import Foundation
import CryptoKit
import UniformTypeIdentifiers

/// Vault files. Each file has its own id (`fileId`); a new file means a new id, so other devices know
/// to fetch it. On this device a file lives at Application Support/OnMission/Files/<fileId>.<ext>,
/// on the server at /v1/files/<fileId>.
enum DocumentFiles {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("OnMission/Files", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Where the file for this fileId lives (or would live) on this device.
    static func fileURL(_ fileID: String, fileName: String) -> URL {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return folder.appendingPathComponent(ext.isEmpty ? fileID : "\(fileID).\(ext)")
    }

    /// nil if this device doesn't have the file.
    static func localURL(_ d: Document) -> URL? {
        guard !d.fileID.isEmpty else { return nil }
        let url = fileURL(d.fileID, fileName: d.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Attach a file picked from Files, a photo or a drop.
    static func attach(from url: URL, to d: Document) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        try attach(data: data, name: url.lastPathComponent, to: d)
    }

    /// Attach bytes (a scan, a photo). Replaces any file the document had.
    static func attach(data: Data, name: String, to d: Document) throws {
        let fileID = newID()
        let cleanName = name.isEmpty ? "file" : name
        try write(data, to: fileURL(fileID, fileName: cleanName))
        let old = d.fileID
        removeLocal(d)
        forgetServerFile(old)
        d.fileID = fileID
        d.fileName = cleanName
        d.mimeType = mimeType(for: cleanName)
        d.sizeBytes = data.count
        d.sha256 = sha256(data)
        d.localFileID = fileID
        d.uploadedFileID = ""
        if d.title.isEmpty { d.title = (cleanName as NSString).deletingPathExtension }
    }

    /// Take the file off this document (the server copy goes on the next sync, if this device uploaded it).
    static func detach(_ d: Document) {
        let old = d.fileID
        removeLocal(d)
        forgetServerFile(old)
        d.fileID = ""
        d.fileName = ""
        d.mimeType = ""
        d.sizeBytes = 0
        d.sha256 = ""
        d.localFileID = ""
        d.uploadedFileID = ""
    }

    /// Fetch the file now (for documents that aren't kept offline on every device).
    @MainActor
    static func download(_ d: Document) async throws {
        guard !d.fileID.isEmpty, localURL(d) == nil else { return }
        guard let api = SyncEngine.shared.api else { throw API.Failure.unauthorized("Log in to your server first.") }
        let fileID = d.fileID
        guard let data = try await api.download(fileID) else {
            throw API.Failure.http(404, code: "not_found", message: "The file isn't on the server yet. Sync the device that added it.")
        }
        try store(data, for: d, fileID: fileID)
    }

    /// Save downloaded bytes, after checking them against the record's checksum.
    static func store(_ data: Data, for d: Document, fileID: String) throws {
        guard d.fileID == fileID else { return }   // the document got another file meanwhile
        if !d.sha256.isEmpty && sha256(data) != d.sha256.lowercased() { throw API.Failure.checksum }
        try write(data, to: fileURL(fileID, fileName: d.fileName))
        d.localFileID = fileID
        d.uploadedFileID = fileID   // it's on the server, so no upload needed
    }

    static func sizeText(_ d: Document) -> String {
        d.sizeBytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(d.sizeBytes), countStyle: .file) : ""
    }

    // MARK: Local files

    static func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    /// Removes whatever file this device holds for the document (the current and any older one).
    static func removeLocal(_ d: Document) {
        removeLocal(fileID: d.fileID)
        if d.localFileID != d.fileID { removeLocal(fileID: d.localFileID) }
        d.localFileID = ""
    }

    static func removeLocal(fileID: String) {
        guard !fileID.isEmpty else { return }
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] where name == fileID || name.hasPrefix(fileID + ".") {
            try? fm.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// Deletes local files no document points at any more (deleted on another device, replaced...).
    /// Files younger than an hour are left alone, in case a screen is still busy attaching one.
    static func removeOrphans(keeping fileIDs: Set<String>) {
        let fm = FileManager.default
        let hourAgo = Date.now.addingTimeInterval(-3600)
        for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] {
            let id = String(name.prefix(36))
            guard !fileIDs.contains(id) else { continue }
            let url = folder.appendingPathComponent(name)
            let modified = (try? fm.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
            if (modified ?? .distantPast) < hourAgo { try? fm.removeItem(at: url) }
        }
    }

    // MARK: Server files this device uploaded, and old ones to delete

    private static let uploadedKey = "files.uploadedHere"
    private static let pendingKey = "files.pendingServerDeletes"

    static func markUploadedHere(_ fileID: String) {
        var set = Set(UserDefaults.standard.stringArray(forKey: uploadedKey) ?? [])
        set.insert(fileID)
        UserDefaults.standard.set(Array(set), forKey: uploadedKey)
    }

    /// A file this document no longer uses: delete it from the server on the next sync,
    /// but only if this device uploaded it.
    static func forgetServerFile(_ fileID: String) {
        guard !fileID.isEmpty else { return }
        var uploaded = Set(UserDefaults.standard.stringArray(forKey: uploadedKey) ?? [])
        guard uploaded.contains(fileID) else { return }
        uploaded.remove(fileID)
        UserDefaults.standard.set(Array(uploaded), forKey: uploadedKey)
        var pending = Set(UserDefaults.standard.stringArray(forKey: pendingKey) ?? [])
        pending.insert(fileID)
        UserDefaults.standard.set(Array(pending), forKey: pendingKey)
    }

    static var pendingServerDeletes: [String] { UserDefaults.standard.stringArray(forKey: pendingKey) ?? [] }

    static func serverDeleteDone(_ fileID: String) {
        let pending = pendingServerDeletes.filter { $0 != fileID }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }

    // MARK: Helpers

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }
}
