import Foundation
import SwiftData

/// Small generic helpers so every record type is handled the same way.
enum Store {
    static func all<T: Syncable>(_ type: T.Type, _ ctx: ModelContext) -> [T] {
        (try? ctx.fetch(FetchDescriptor<T>())) ?? []
    }

    static func find<T: Syncable>(_ type: T.Type, id: String, _ ctx: ModelContext) -> T? {
        all(type, ctx).first { $0.id == id }
    }

    /// The one shared settings record. If it's missing it's made with the defaults and counted as
    /// "already synced", so a fresh device never pushes defaults over the real settings on the server.
    static func settings(_ ctx: ModelContext) -> MissionSettings {
        if let s = find(MissionSettings.self, id: MissionSettings.mainID, ctx) { return s }
        let s = MissionSettings()
        ctx.insert(s)
        s.syncedFingerprint = Fingerprint.of(s.data)
        return s
    }

    /// Delete something. Leaves a tombstone so the server and other devices delete it too,
    /// and removes links pointing at it. A checklist takes its items with it; a document its file.
    static func delete<T: Syncable>(_ item: T, in ctx: ModelContext) {
        let key = item.key
        for other in AnyRecord.everything(ctx) where other.id != key {
            let m = other.model
            let links = m.links
            if links.contains(where: { $0.key == key }) {
                m.links = links.filter { $0.key != key }
            }
        }
        if let list = item as? Checklist {
            for row in all(Todo.self, ctx) where row.checklistID == list.id {
                delete(row, in: ctx)
            }
        }
        if let doc = item as? Document {
            DocumentFiles.forgetServerFile(doc.fileID)
            DocumentFiles.removeLocal(doc)
        }
        ctx.insert(Tombstone(id: item.id, collection: T.collection, lastData: Fingerprint.encode(item.data)))
        ctx.delete(item)
    }

    /// Ids deleted here whose tombstone hasn't reached the server yet.
    static func pendingDeletes(_ ctx: ModelContext) -> Set<String> {
        Set(((try? ctx.fetch(FetchDescriptor<Tombstone>())) ?? []).map(\.id))
    }
}

// MARK: - Registry: one entry per collection, so sync, seed and backup can treat every type alike

struct RecordKind {
    let collection: String
    let all: (ModelContext) -> [any Syncable]
    let find: (ModelContext, String) -> (any Syncable)?
    /// Apply records from the server, the seed or a backup (all of this collection).
    /// `force` overwrites unsent local edits too (restore, or a stale rejection).
    let apply: (ModelContext, [API.Record], Bool) -> Void

    static func of<T: Syncable>(_ type: T.Type) -> RecordKind {
        RecordKind(
            collection: T.collection,
            all: { ctx in Store.all(T.self, ctx) },
            find: { ctx, id in Store.find(T.self, id: id, ctx) },
            apply: { ctx, records, force in applyRecords(T.self, records, force: force, ctx) }
        )
    }

    private static func applyRecords<T: Syncable>(_ type: T.Type, _ records: [API.Record], force: Bool, _ ctx: ModelContext) {
        var byID: [String: T] = [:]
        for item in Store.all(T.self, ctx) { byID[item.id] = item }
        for r in records {
            let existing = byID[r.id]
            if r.deletedAt != nil {
                // Deleted on the server (or another device): delete here too.
                if let existing {
                    if let doc = existing as? Document { DocumentFiles.removeLocal(doc) }
                    ctx.delete(existing)
                    byID[r.id] = nil
                }
                continue
            }
            // Edited here since the last sync: keep it, it goes up on the next push and wins there.
            if let existing, existing.isChangedLocally, !force { continue }
            let item: T
            if let existing {
                item = existing
            } else {
                item = T(id: r.id)
                ctx.insert(item)
                byID[r.id] = item
            }
            item.load(r.data)
            if let created = r.createdAt.flatMap(TimeFormat.date) { item.createdAt = created }
            item.updatedAt = TimeFormat.date(r.updatedAt) ?? .now
            item.syncedFingerprint = Fingerprint.of(item.data)
        }
    }
}

enum Registry {
    /// Settings first, so screens that open during a first sync see the right departure date.
    static let kinds: [RecordKind] = [
        .of(MissionSettings.self), .of(Checklist.self), .of(Todo.self), .of(Partner.self), .of(Gift.self),
        .of(BudgetEntry.self), .of(SellItem.self), .of(PackingItem.self), .of(Note.self), .of(Document.self),
        .of(Contact.self), .of(Newsletter.self),
    ]

    static func kind(_ collection: String) -> RecordKind? {
        kinds.first { $0.collection == collection }
    }

    /// Apply a mixed list of records, keeping their order within each collection.
    static func apply(_ records: [API.Record], _ ctx: ModelContext, force: Bool = false) {
        var groups: [String: [API.Record]] = [:]
        for r in records { groups[r.collection, default: []].append(r) }
        for kind in kinds {
            if let list = groups[kind.collection], !list.isEmpty { kind.apply(ctx, list, force) }
        }
    }
}

// MARK: - AnyRecord: any record a person can open, link to or search for

enum AnyRecord: Identifiable {
    case task(Todo), checklist(Checklist), partner(Partner), gift(Gift), budget(BudgetEntry), sell(SellItem)
    case packing(PackingItem), note(Note), document(Document), contact(Contact), newsletter(Newsletter)

    init?(_ model: any Syncable) {
        if let x = model as? Todo { self = .task(x) }
        else if let x = model as? Checklist { self = .checklist(x) }
        else if let x = model as? Partner { self = .partner(x) }
        else if let x = model as? Gift { self = .gift(x) }
        else if let x = model as? BudgetEntry { self = .budget(x) }
        else if let x = model as? SellItem { self = .sell(x) }
        else if let x = model as? PackingItem { self = .packing(x) }
        else if let x = model as? Note { self = .note(x) }
        else if let x = model as? Document { self = .document(x) }
        else if let x = model as? Contact { self = .contact(x) }
        else if let x = model as? Newsletter { self = .newsletter(x) }
        else { return nil }
    }

    var model: any Syncable {
        switch self {
        case .task(let x): x
        case .checklist(let x): x
        case .partner(let x): x
        case .gift(let x): x
        case .budget(let x): x
        case .sell(let x): x
        case .packing(let x): x
        case .note(let x): x
        case .document(let x): x
        case .contact(let x): x
        case .newsletter(let x): x
        }
    }

    /// "tasks/<uuid>", the same as RecordLink.key.
    var id: String { model.key }
    var title: String { model.displayTitle }

    var typeLabel: String {
        switch self {
        case .note(let n): n.kindValue == .prayer ? "Prayer point" : n.kindValue.title
        case .task(let t): t.checklistID.isEmpty ? Todo.typeLabel : "Checklist item"
        default: type(of: model).typeLabel
        }
    }

    var symbol: String {
        switch self {
        case .task(let t): t.isDone ? "checkmark.square.fill" : "square"
        case .checklist: "checklist"
        case .partner(let p): p.stageValue.symbol
        case .gift: "gift"
        case .budget(let b): b.kindValue == .income ? "arrow.down.circle" : "eurosign.circle"
        case .sell: "tag"
        case .packing(let p): p.packed ? "suitcase.fill" : "suitcase"
        case .note(let n): n.kindValue.symbol
        case .document(let d): d.kindValue.symbol
        case .contact: "person.crop.rectangle"
        case .newsletter: "envelope.open"
        }
    }

    var accent: Accent {
        switch self {
        case .task(let t): t.areaValue.accent
        case .checklist(let c): c.areaValue.accent
        case .partner(let p): p.stageValue.accent
        case .gift: .green
        case .budget: .green
        case .sell(let s): s.statusValue.accent
        case .packing: .lime
        case .note(let n): n.kindValue == .prayer ? .purple : .sand
        case .document: .purple
        case .contact: .grey
        case .newsletter(let n): n.statusValue.accent
        }
    }

    var subtitle: String {
        switch self {
        case .task(let t):
            let parts: [String?] = [t.areaValue.title, t.statusValue == .todo ? nil : t.statusValue.title, t.dueDate.map(Self.day)]
            return parts.compactMap { $0 }.joined(separator: " · ")
        case .checklist(let c):
            return [c.phaseValue.title, c.areaValue.title].joined(separator: " · ")
        case .partner(let p):
            let money = p.monthlyCents > 0 ? Money.text(p.monthlyCents, p.currency) + " / month" : nil
            let parts: [String?] = [p.stageValue.title, money]
            return parts.compactMap { $0 }.joined(separator: " · ")
        case .gift(let g):
            return [Money.text(g.amountCents, g.currency), g.recurring ? "monthly" : "one-off", Self.day(g.date)].joined(separator: " · ")
        case .budget(let b):
            let per = b.recurrenceValue == .once ? "one-off" : "per " + (b.recurrenceValue == .monthly ? "month" : "year")
            return [b.kindValue.title, Money.text(b.amountCents, b.currency) + " " + per].joined(separator: " · ")
        case .sell(let s):
            let price = s.askingCents > 0 ? Money.text(s.askingCents, s.currency) : nil
            let parts: [String?] = [s.statusValue.title, price]
            return parts.compactMap { $0 }.joined(separator: " · ")
        case .packing(let p):
            let parts: [String?] = [p.bagValue.title, p.quantity > 1 ? "\(p.quantity)×" : nil, p.packed ? "packed" : nil]
            return parts.compactMap { $0 }.joined(separator: " · ")
        case .note(let n):
            if n.kindValue == .prayer { return n.answeredAt == nil ? "Prayer point" : "Answered " + Self.day(n.answeredAt!) }
            return n.kindValue.title
        case .document(let d):
            let parts: [String?] = [d.kindValue.title, d.hasFile ? "file" : "no file yet", d.expiresAt.map { "expires " + Self.day($0) }]
            return parts.compactMap { $0 }.joined(separator: " · ")
        case .contact(let c):
            return [c.role, c.organisation].filter { !$0.isEmpty }.joined(separator: " · ")
        case .newsletter(let n):
            let parts: [String?] = [n.number > 0 ? "#\(n.number)" : nil, n.statusValue.title, n.plannedDate.map(Self.day)]
            return parts.compactMap { $0 }.joined(separator: " · ")
        }
    }

    /// Everything worth searching in, as one lowercase-insensitive string.
    var searchText: String {
        let parts: [String]
        switch self {
        case .task(let t): parts = [t.title, t.notes, t.area, t.waitingOn]
        case .checklist(let c): parts = [c.title, c.desc, c.area]
        case .partner(let p): parts = [p.name, p.email, p.phone, p.church, p.notes, p.nextStep, p.address]
        case .gift(let g): parts = [g.via, g.notes, Money.text(g.amountCents, g.currency)]
        case .budget(let b): parts = [b.label, b.category, b.notes]
        case .sell(let s): parts = [s.name, s.platform, s.buyer, s.location, s.notes]
        case .packing(let p): parts = [p.name, p.category, p.notes]
        case .note(let n): parts = [n.title, n.body]
        case .document(let d): parts = [d.title, d.kindValue.title, d.fileName, d.number, d.notes]
        case .contact(let c): parts = [c.name, c.role, c.organisation, c.email, c.phone, c.address, c.notes]
        case .newsletter(let n): parts = [n.title, n.body, n.notes]
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func everything(_ ctx: ModelContext) -> [AnyRecord] {
        var out: [AnyRecord] = []
        out += Store.all(Todo.self, ctx).map(AnyRecord.task)
        out += Store.all(Checklist.self, ctx).map(AnyRecord.checklist)
        out += Store.all(Partner.self, ctx).map(AnyRecord.partner)
        out += Store.all(Gift.self, ctx).map(AnyRecord.gift)
        out += Store.all(BudgetEntry.self, ctx).map(AnyRecord.budget)
        out += Store.all(SellItem.self, ctx).map(AnyRecord.sell)
        out += Store.all(PackingItem.self, ctx).map(AnyRecord.packing)
        out += Store.all(Note.self, ctx).map(AnyRecord.note)
        out += Store.all(Document.self, ctx).map(AnyRecord.document)
        out += Store.all(Contact.self, ctx).map(AnyRecord.contact)
        out += Store.all(Newsletter.self, ctx).map(AnyRecord.newsletter)
        return out
    }

    /// The record a link points at, or nil if it was deleted (show it as "removed").
    static func resolve(_ link: RecordLink, _ ctx: ModelContext) -> AnyRecord? {
        guard link.collection != MissionSettings.collection,
              let model = Registry.kind(link.collection)?.find(ctx, link.id) else { return nil }
        return AnyRecord(model)
    }

    private static func day(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }
}

// MARK: - Links

/// Smart links: a RecordLink in `data.links` of one side, shown on both sides.
enum Links {
    static func link(_ a: AnyRecord, _ b: AnyRecord, _ ctx: ModelContext) {
        guard a.id != b.id else { return }
        let ma = a.model
        let mb = b.model
        if ma.links.contains(where: { $0.key == b.id }) || mb.links.contains(where: { $0.key == a.id }) { return }
        ma.links = ma.links + [mb.asLink]
    }

    static func unlink(_ a: AnyRecord, _ b: AnyRecord, _ ctx: ModelContext) {
        let ma = a.model
        let mb = b.model
        let la = ma.links
        if la.contains(where: { $0.key == b.id }) { ma.links = la.filter { $0.key != b.id } }
        let lb = mb.links
        if lb.contains(where: { $0.key == a.id }) { mb.links = lb.filter { $0.key != a.id } }
    }

    /// Everything linked to this record, in both directions. A gift also shows its partner (and the other way round).
    static func linked(to r: AnyRecord, _ ctx: ModelContext) -> [AnyRecord] {
        var seen = Set<String>([r.id])
        var out: [AnyRecord] = []
        func add(_ x: AnyRecord?) {
            guard let x, !seen.contains(x.id) else { return }
            seen.insert(x.id)
            out.append(x)
        }
        for link in r.model.links { add(AnyRecord.resolve(link, ctx)) }
        for other in AnyRecord.everything(ctx) where other.id != r.id {
            if other.model.links.contains(where: { $0.key == r.id }) { add(other) }
        }
        switch r {
        case .gift(let g):
            if !g.partnerID.isEmpty { add(Store.find(Partner.self, id: g.partnerID, ctx).map(AnyRecord.partner)) }
        case .partner(let p):
            for g in Store.all(Gift.self, ctx) where g.partnerID == p.id { add(.gift(g)) }
        default: break
        }
        return out.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
