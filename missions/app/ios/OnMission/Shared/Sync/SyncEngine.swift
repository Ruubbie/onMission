import Foundation
import SwiftData
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// Keeps this device and your server in step.
/// Everything is saved on the device first; a sync sends what changed here and fetches what changed elsewhere.
@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    var serverURL: String
    var email: String
    var isLoggedIn: Bool
    var isSyncing = false
    var lastSync: Date?
    var lastError: String?
    /// Bumps after every sync, so views that keep their own lists can refresh.
    var revision = 0

    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        let server = d.string(forKey: "sync.serverURL") ?? ""
        serverURL = server
        email = d.string(forKey: "sync.email") ?? ""
        lastSync = d.object(forKey: "sync.lastSync") as? Date
        isLoggedIn = Keychain.token != nil && API.baseURL(server) != nil
    }

    /// A client for the saved server and token, or nil when logged out.
    var api: API? {
        guard isLoggedIn, let base = API.baseURL(serverURL), let token = Keychain.token else { return nil }
        return API(base: base, token: token)
    }

    // MARK: Cursor (per server and account)

    private var cursorKey: String { "sync.cursor|\(serverURL)|\(email)" }
    private var cursor: String? {
        get { defaults.string(forKey: cursorKey) }
        set {
            if let newValue { defaults.set(newValue, forKey: cursorKey) } else { defaults.removeObject(forKey: cursorKey) }
        }
    }

    // MARK: Account

    func login(server: String, email: String, password: String) async throws {
        guard let base = API.baseURL(server) else { throw API.Failure.badAddress }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let session = try await API(base: base, token: nil)
            .login(email: cleanEmail, password: password, device: Self.deviceInfo)
        Keychain.token = session.token
        serverURL = base.absoluteString
        self.email = cleanEmail
        defaults.set(serverURL, forKey: "sync.serverURL")
        defaults.set(cleanEmail, forKey: "sync.email")
        isLoggedIn = true
        lastError = nil
    }

    /// Logs this device out on the server too. Your data stays on the device.
    func logout() async {
        if let api { try? await api.logout() }
        Keychain.token = nil
        isLoggedIn = false
    }

    func testConnection() async -> String {
        guard let base = API.baseURL(serverURL) else { return "Fill in your server address first." }
        do {
            try await API(base: base, token: nil).health()
            guard let api else { return "The server is reachable. Log in to sync." }
            let me = try await api.me()
            return "Connected as \(me.user.name) (\(me.user.email)) on \(me.device.name)."
        } catch {
            if API.Failure.isUnauthorized(error) { handleLoggedOut() }
            return error.localizedDescription
        }
    }

    func devices() async throws -> [API.Device] {
        guard let api else { throw API.Failure.unauthorized("") }
        return try await api.devices()
    }

    func revokeDevice(_ id: String) async throws {
        guard let api else { throw API.Failure.unauthorized("") }
        try await api.revokeDevice(id)
    }

    private func handleLoggedOut() {
        Keychain.token = nil
        isLoggedIn = false
    }

    static var deviceInfo: API.DeviceInfo {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        #if canImport(UIKit)
        let name = UIDevice.current.name
        #else
        let name = Host.current().localizedName ?? "Mac"
        #endif
        #if os(iOS)
        let platform = "ios"
        #else
        let platform = "other"
        #endif
        return API.DeviceInfo(name: name, platform: platform, appVersion: version)
    }

    // MARK: Sync

    func sync(_ ctx: ModelContext) async {
        guard let api, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let problems = try await run(api, ctx)
            lastError = problems.isEmpty ? nil : problems.joined(separator: "\n")
            lastSync = .now
            defaults.set(lastSync, forKey: "sync.lastSync")
        } catch {
            if API.Failure.isUnauthorized(error) { handleLoggedOut() }
            lastError = error.localizedDescription
        }
        try? ctx.save()
        revision += 1
        await Reminders.refresh(ctx)
    }

    /// One full round. Returns problems worth showing that didn't stop the sync (invalid records, file errors).
    private func run(_ api: API, _ ctx: ModelContext) async throws -> [String] {
        var problems: [String] = []

        // 1. Files first: the contract says upload the file, then sync the record pointing at it.
        problems += await uploadFiles(api, ctx)

        // 2. Push local edits and deletes in chunks of 500; every answer also brings a page of server changes.
        let outgoing = collectChanges(ctx)
        var chunks: [[Outgoing]] = stride(from: 0, to: outgoing.count, by: 500).map {
            Array(outgoing[$0..<min($0 + 500, outgoing.count)])
        }
        if chunks.isEmpty { chunks = [[]] }
        var hasMore = false
        var reset = false
        for chunk in chunks {
            let response = try await api.sync(cursor: cursor, changes: chunk.map(\.change))
            problems += handleOutcome(response, sent: chunk, ctx)
            if response.resetRequired { reset = true; break }
            Registry.apply(response.changes, ctx)
            cursor = response.cursor
            hasMore = response.hasMore
            try ctx.save()
        }

        // 3. Pull the rest.
        while hasMore && !reset {
            let response = try await api.sync(cursor: cursor, changes: [])
            if response.resetRequired { reset = true; break }
            Registry.apply(response.changes, ctx)
            cursor = response.cursor
            hasMore = response.hasMore
            try ctx.save()
        }

        // 4. Cursor too old (this device was away for more than 180 days): download everything again.
        if reset { try await fullResync(api, ctx) }

        // 5. Files: fetch offline copies, tidy up, delete server files this device replaced.
        problems += await downloadFiles(api, ctx)
        await deleteOldServerFiles(api, ctx)
        try ctx.save()
        return problems
    }

    /// One change on its way to the server, and what to do when it's accepted.
    private struct Outgoing {
        var change: API.Change
        /// The fingerprint sent, for an edit; nil for a delete.
        var fingerprint: String?
    }

    /// Everything that changed here: edits (found by fingerprint) and deletes (tombstones).
    private func collectChanges(_ ctx: ModelContext) -> [Outgoing] {
        let now = Date.now
        let stamp = TimeFormat.string(now)
        let deleted = Store.pendingDeletes(ctx)
        var out: [Outgoing] = []
        for kind in Registry.kinds {
            for model in kind.all(ctx) where !deleted.contains(model.id) {
                let data = model.data
                let fp = Fingerprint.of(data)
                guard fp != model.syncedFingerprint else { continue }
                model.updatedAt = now
                out.append(Outgoing(change: API.Change(id: model.id, collection: kind.collection, updatedAt: stamp,
                                                       deletedAt: nil, data: data), fingerprint: fp))
            }
        }
        for t in (try? ctx.fetch(FetchDescriptor<Tombstone>())) ?? [] {
            out.append(Outgoing(change: API.Change(id: t.id, collection: t.collection, updatedAt: stamp,
                                                   deletedAt: stamp, data: Fingerprint.decode(t.lastData)), fingerprint: nil))
        }
        return out
    }

    /// Marks accepted changes as synced and settles rejected ones.
    private func handleOutcome(_ response: API.SyncResponse, sent: [Outgoing], _ ctx: ModelContext) -> [String] {
        var byID: [String: Outgoing] = [:]
        for o in sent { byID[o.change.id] = o }
        let tombstones = (try? ctx.fetch(FetchDescriptor<Tombstone>())) ?? []
        var problems: [String] = []

        for a in response.accepted {
            guard let o = byID[a.id] else { continue }
            if let fp = o.fingerprint {
                // If it was edited again while we waited, the fingerprint no longer matches and it goes next time.
                if let model = Registry.kind(o.change.collection)?.find(ctx, a.id) { model.syncedFingerprint = fp }
            } else {
                for t in tombstones where t.id == a.id { ctx.delete(t) }
            }
        }

        for r in response.rejected {
            let o = byID[r.id]
            switch r.reason {
            case "stale":
                // The server has a newer version: it wins. A delete that lost brings the record back.
                guard let current = r.current else { continue }   // lost a race; it goes again next sync
                for t in tombstones where t.id == r.id { ctx.delete(t) }
                Registry.apply([current], ctx, force: true)
            default:
                // invalid or forbidden: keep the local copy and say so.
                let collection = o?.change.collection ?? "record"
                let title = o.flatMap { Registry.kind($0.change.collection)?.find(ctx, $0.change.id)?.displayTitle } ?? r.id
                problems.append("The server refused \(collection) “\(title)”: \(r.message ?? r.reason)")
            }
        }
        return problems
    }

    /// Downloads everything from scratch. Local records the server no longer has (and that weren't
    /// changed here) were deleted long ago on another device, so they go here too.
    private func fullResync(_ api: API, _ ctx: ModelContext) async throws {
        cursor = nil
        var seen = Set<String>()
        var next: String? = nil
        var more = true
        while more {
            let response = try await api.sync(cursor: next, changes: [])
            Registry.apply(response.changes, ctx)
            for r in response.changes where r.deletedAt == nil { seen.insert(r.id) }
            next = response.cursor
            more = response.hasMore
        }
        for kind in Registry.kinds where kind.collection != MissionSettings.collection {
            for model in kind.all(ctx) where !seen.contains(model.id) && !model.isChangedLocally {
                if let doc = model as? Document { DocumentFiles.removeLocal(doc) }
                ctx.delete(model)
            }
        }
        cursor = next
        try ctx.save()
    }

    // MARK: Files

    /// New files added on this device go up (HEAD first, so a retry doesn't send them twice).
    private func uploadFiles(_ api: API, _ ctx: ModelContext) async -> [String] {
        var problems: [String] = []
        for d in Store.all(Document.self, ctx) where !d.fileID.isEmpty && d.uploadedFileID != d.fileID {
            guard let url = DocumentFiles.localURL(d) else { continue }   // another device has it
            let fileID = d.fileID
            do {
                let exists = try await api.fileExists(fileID)
                if exists {
                    d.uploadedFileID = fileID
                    continue
                }
                var sha = d.sha256
                if sha.isEmpty { sha = DocumentFiles.sha256(try Data(contentsOf: url)) }
                try await api.upload(fileID, from: url, mimeType: d.mimeType, fileName: d.fileName, sha256: sha)
                DocumentFiles.markUploadedHere(fileID)
                if d.fileID == fileID { d.uploadedFileID = fileID }
            } catch {
                if API.Failure.isUnauthorized(error) { return problems }
                problems.append("Couldn't upload “\(d.displayTitle)”: \(error.localizedDescription)")
            }
        }
        return problems
    }

    /// Documents marked "offline" get a copy on every device. Old local copies are cleaned up.
    private func downloadFiles(_ api: API, _ ctx: ModelContext) async -> [String] {
        var problems: [String] = []
        let docs = Store.all(Document.self, ctx)
        for d in docs {
            // The document got a new file elsewhere: the old local copy goes.
            if !d.localFileID.isEmpty && d.localFileID != d.fileID {
                DocumentFiles.removeLocal(fileID: d.localFileID)
                d.localFileID = ""
            }
            if DocumentFiles.localURL(d) != nil {
                if d.localFileID.isEmpty { d.localFileID = d.fileID }
                continue
            }
            guard d.offline, !d.fileID.isEmpty else { continue }
            let fileID = d.fileID
            do {
                // nil: not uploaded yet by the device that added it. Try again next sync.
                guard let data = try await api.download(fileID) else { continue }
                try DocumentFiles.store(data, for: d, fileID: fileID)
            } catch {
                problems.append("Couldn't download “\(d.displayTitle)”: \(error.localizedDescription)")
            }
        }
        DocumentFiles.removeOrphans(keeping: Set(Store.all(Document.self, ctx).map(\.fileID).filter { !$0.isEmpty }))
        return problems
    }

    /// Files this device uploaded and then replaced or deleted. Only once no document uses them any more.
    private func deleteOldServerFiles(_ api: API, _ ctx: ModelContext) async {
        let inUse = Set(Store.all(Document.self, ctx).map(\.fileID))
        for fileID in DocumentFiles.pendingServerDeletes {
            if inUse.contains(fileID) {
                DocumentFiles.serverDeleteDone(fileID)   // back in use (e.g. a stale rejection restored it)
                continue
            }
            do {
                try await api.deleteFile(fileID)
                DocumentFiles.serverDeleteDone(fileID)
            } catch {
                // Try again next sync.
            }
        }
    }
}
