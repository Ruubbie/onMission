import Foundation
import SwiftData

// Every model mirrors one collection of the shared API (app/api/openapi.yaml), so the iPhone app
// and the Windows helper read and write the same records.
//
// How a record is stored here:
// - `rawData` is the record's full `data` object as last received or written, including fields this
//   app doesn't know (written by the Windows helper or a newer version). They are sent back untouched.
// - The typed properties are what the screens edit. `known` turns them back into JSON; on the way out
//   they are laid over `rawData`.
// - `syncedFingerprint` is a hash of `data` at the last sync. If it differs now, the record changed here.

protocol Syncable: PersistentModel {
    /// The API collection, e.g. "tasks".
    static var collection: String { get }
    /// "Task", "Partner"…, for search results and link chips.
    static var typeLabel: String { get }
    var id: String { get }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var syncedFingerprint: String { get set }
    var rawData: Data { get set }
    /// The fields this app manages. A nil value removes that key from `data`.
    var known: [String: JSONValue?] { get }
    /// Fill the typed properties from `data`.
    func read(_ d: JSONObject)
    var displayTitle: String { get }
    init(id: String)
}

/// One entry of a record's `data.links`.
struct RecordLink: Codable, Hashable {
    var collection: String
    var id: String
    var label: String?

    var key: String { "\(collection)/\(id)" }

    var json: JSONValue {
        var o: JSONObject = ["collection": .string(collection), "id": .string(id)]
        if let label, !label.isEmpty { o["label"] = .string(label) }
        return .object(o)
    }

    init(collection: String, id: String, label: String? = nil) {
        self.collection = collection
        self.id = id
        self.label = label
    }

    init?(_ v: JSONValue) {
        guard let o = v.objectValue, let c = o["collection"]?.stringValue, let i = o["id"]?.stringValue else { return nil }
        collection = c
        id = i
        label = o["label"]?.stringValue
    }
}

extension Syncable {
    /// "tasks/6f1c…", the same key a RecordLink has.
    var key: String { "\(Self.collection)/\(id)" }
    var asLink: RecordLink { RecordLink(collection: Self.collection, id: id) }

    /// The full `data` to send: everything we received, with our edits laid over it.
    var data: JSONObject {
        var d = Fingerprint.decode(rawData)
        for (k, v) in known { d[k] = v }
        return d
    }

    /// Take a `data` object from the server, the seed or a backup.
    func load(_ d: JSONObject) {
        rawData = Fingerprint.encode(d)
        read(d)
    }

    var isChangedLocally: Bool { Fingerprint.of(data) != syncedFingerprint }

    /// Links stored on this record (`data.links`). Use `Links` to read both directions.
    var links: [RecordLink] {
        get { (Fingerprint.decode(rawData)["links"]?.arrayValue ?? []).compactMap(RecordLink.init) }
        nonmutating set {
            var d = Fingerprint.decode(rawData)
            d["links"] = newValue.isEmpty ? nil : .array(newValue.map(\.json))
            rawData = Fingerprint.encode(d)
        }
    }
}

// MARK: - tasks

@Model final class Todo: Syncable {
    static var collection: String { "tasks" }
    static var typeLabel: String { "Task" }
    @Attribute(.unique) var id: String
    var title: String = ""
    var notes: String = ""
    var status: String = TaskStatus.todo.rawValue
    var area: String = Area.other.rawValue
    var priority: String = Priority.normal.rawValue
    var dueDate: Date? = nil
    var remindAt: Date? = nil
    var completedAt: Date? = nil
    /// The checklist this task belongs to ("" for none). Checklist items are tasks.
    var checklistID: String = ""
    var waitingOn: String = ""
    var sourceURL: String = ""
    var order: Double = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }

    var statusValue: TaskStatus {
        get { TaskStatus(rawValue: status) ?? .todo }
        set { status = newValue.rawValue }
    }
    var areaValue: Area {
        get { Area(rawValue: area) ?? .other }
        set { area = newValue.rawValue }
    }
    var priorityValue: Priority {
        get { Priority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
    var isDone: Bool { statusValue == .done || statusValue == .skipped }
    var isOverdue: Bool { !isDone && (dueDate.map { $0 < Calendar.current.startOfDay(for: .now) } ?? false) }
    var displayTitle: String { title.isEmpty ? "Untitled task" : title }

    func setDone(_ done: Bool) {
        statusValue = done ? .done : .todo
        completedAt = done ? .now : nil
    }

    var known: [String: JSONValue?] {
        ["title": .str(title), "notes": .text(notes), "status": .str(status), "area": .str(area),
         "priority": .str(priority), "dueDate": .day(dueDate), "remindAt": .time(remindAt),
         "completedAt": .time(completedAt), "checklistId": .text(checklistID), "waitingOn": .text(waitingOn),
         "sourceUrl": .text(sourceURL), "order": .dbl(order)]
    }
    func read(_ d: JSONObject) {
        title = d.str("title"); notes = d.str("notes"); status = d.str("status", "todo"); area = d.str("area", "other")
        priority = d.str("priority", "normal"); dueDate = d.day("dueDate"); remindAt = d.time("remindAt")
        completedAt = d.time("completedAt"); checklistID = d.str("checklistId"); waitingOn = d.str("waitingOn")
        sourceURL = d.str("sourceUrl"); order = d.dbl("order")
    }
}

// MARK: - checklists (their items are tasks with checklistId)

@Model final class Checklist: Syncable {
    static var collection: String { "checklists" }
    static var typeLabel: String { "Checklist" }
    @Attribute(.unique) var id: String
    var title: String = ""
    var desc: String = ""
    var area: String = Area.other.rawValue
    var phase: String = ChecklistPhase.now.rawValue
    var archived: Bool = false
    var order: Double = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var areaValue: Area {
        get { Area(rawValue: area) ?? .other }
        set { area = newValue.rawValue }
    }
    var phaseValue: ChecklistPhase {
        get { ChecklistPhase(rawValue: phase) ?? .now }
        set { phase = newValue.rawValue }
    }
    var displayTitle: String { title.isEmpty ? "Untitled checklist" : title }

    var known: [String: JSONValue?] {
        ["title": .str(title), "description": .text(desc), "area": .str(area), "phase": .str(phase),
         "archived": archived ? .flag(true) : nil, "order": .dbl(order)]
    }
    func read(_ d: JSONObject) {
        title = d.str("title"); desc = d.str("description"); area = d.str("area", "other")
        phase = d.str("phase", "now"); archived = d.bool("archived"); order = d.dbl("order")
    }
}

// MARK: - partners

@Model final class Partner: Syncable {
    static var collection: String { "partners" }
    static var typeLabel: String { "Partner" }
    @Attribute(.unique) var id: String
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var church: String = ""
    var stage: String = PartnerStage.idea.rawValue
    var monthlyCents: Int = 0
    var oneOffCents: Int = 0
    var currency: String = "EUR"
    var startDate: Date? = nil
    var prayer: Bool = false
    var newsletter: Bool = false
    var lastContact: Date? = nil
    var nextFollowUp: Date? = nil
    var thankedAt: Date? = nil
    var notes: String = ""
    // Extra fields (not in the contract, kept by the server): see design notes in the README.
    var category: String = PartnerCategory.b.rawValue
    var nextStep: String = ""
    var address: String = ""
    var birthday: Date? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var stageValue: PartnerStage {
        get { PartnerStage(rawValue: stage) ?? .idea }
        set { stage = newValue.rawValue }
    }
    var categoryValue: PartnerCategory {
        get { PartnerCategory(rawValue: category) ?? .b }
        set { category = newValue.rawValue }
    }
    var displayTitle: String { name.isEmpty ? "New partner" : name }
    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    var known: [String: JSONValue?] {
        ["name": .str(name), "email": .text(email), "phone": .text(phone), "church": .text(church),
         "stage": .str(stage), "monthlyCents": monthlyCents > 0 ? .int(monthlyCents) : nil,
         "oneOffCents": oneOffCents > 0 ? .int(oneOffCents) : nil, "currency": .str(currency),
         "startDate": .day(startDate), "prayer": prayer ? .flag(true) : nil, "newsletter": newsletter ? .flag(true) : nil,
         "lastContactAt": .day(lastContact), "nextFollowUp": .day(nextFollowUp), "thankedAt": .day(thankedAt),
         "notes": .text(notes), "category": .str(category), "nextStep": .text(nextStep),
         "address": .text(address), "birthday": .day(birthday)]
    }
    func read(_ d: JSONObject) {
        name = d.str("name"); email = d.str("email"); phone = d.str("phone"); church = d.str("church")
        stage = d.str("stage", "idea"); monthlyCents = d.int("monthlyCents"); oneOffCents = d.int("oneOffCents")
        currency = d.str("currency", "EUR"); startDate = d.day("startDate"); prayer = d.bool("prayer")
        newsletter = d.bool("newsletter"); lastContact = d.day("lastContactAt"); nextFollowUp = d.day("nextFollowUp")
        thankedAt = d.day("thankedAt"); notes = d.str("notes"); category = d.str("category", "B")
        nextStep = d.str("nextStep"); address = d.str("address"); birthday = d.day("birthday")
    }
}

// MARK: - gifts (money actually received)

@Model final class Gift: Syncable {
    static var collection: String { "gifts" }
    static var typeLabel: String { "Gift" }
    @Attribute(.unique) var id: String
    var partnerID: String = ""
    var amountCents: Int = 0
    var currency: String = "EUR"
    var date: Date = Date.now
    var recurring: Bool = false
    var via: String = ""
    var thankedAt: Date? = nil
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var displayTitle: String { "Gift \(Money.text(amountCents, currency)) on \(DayFormat.string(date))" }

    var known: [String: JSONValue?] {
        ["partnerId": .text(partnerID), "amountCents": .int(amountCents), "currency": .str(currency),
         "date": .day(date), "recurring": recurring ? .flag(true) : nil, "via": .text(via),
         "thankedAt": .day(thankedAt), "notes": .text(notes)]
    }
    func read(_ d: JSONObject) {
        partnerID = d.str("partnerId"); amountCents = d.int("amountCents"); currency = d.str("currency", "EUR")
        date = d.day("date") ?? .now; recurring = d.bool("recurring"); via = d.str("via")
        thankedAt = d.day("thankedAt"); notes = d.str("notes")
    }
}

// MARK: - budget

@Model final class BudgetEntry: Syncable {
    static var collection: String { "budget" }
    static var typeLabel: String { "Budget line" }
    @Attribute(.unique) var id: String
    var kind: String = BudgetKind.expense.rawValue
    var label: String = ""
    var category: String = ""
    var amountCents: Int = 0
    var currency: String = "EUR"
    var recurrence: String = Recurrence.once.rawValue
    var date: Date? = nil
    var phase: String = BudgetPhase.setup.rawValue
    var paid: Bool = false
    var notes: String = ""
    var order: Double = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var kindValue: BudgetKind {
        get { BudgetKind(rawValue: kind) ?? .expense }
        set { kind = newValue.rawValue }
    }
    var recurrenceValue: Recurrence {
        get { Recurrence(rawValue: recurrence) ?? .once }
        set { recurrence = newValue.rawValue }
    }
    var phaseValue: BudgetPhase {
        get { BudgetPhase(rawValue: phase) ?? .setup }
        set { phase = newValue.rawValue }
    }
    /// Monthly running cost (or income) rather than a one-off.
    var isMonthly: Bool { phaseValue == .monthly || recurrenceValue == .monthly }
    var displayTitle: String { label.isEmpty ? "Budget line" : label }

    var known: [String: JSONValue?] {
        ["kind": .str(kind), "label": .str(label), "category": .text(category), "amountCents": .int(amountCents),
         "currency": .str(currency), "recurrence": .str(recurrence), "date": .day(date), "phase": .str(phase),
         "paid": paid ? .flag(true) : nil, "notes": .text(notes), "order": .dbl(order)]
    }
    func read(_ d: JSONObject) {
        kind = d.str("kind", "expense"); label = d.str("label"); category = d.str("category")
        amountCents = d.int("amountCents"); currency = d.str("currency", "EUR"); recurrence = d.str("recurrence", "once")
        date = d.day("date"); phase = d.str("phase", "setup"); paid = d.bool("paid"); notes = d.str("notes")
        order = d.dbl("order")
    }
}

// MARK: - sellItems

@Model final class SellItem: Syncable {
    static var collection: String { "sellItems" }
    static var typeLabel: String { "Item to sell" }
    @Attribute(.unique) var id: String
    var name: String = ""
    var status: String = SellStatus.decide.rawValue
    var askingCents: Int = 0
    var soldCents: Int = 0
    var currency: String = "EUR"
    var platform: String = ""
    var listingURL: String = ""
    var buyer: String = ""
    var pickupDate: Date? = nil
    var location: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var statusValue: SellStatus {
        get { SellStatus(rawValue: status) ?? .decide }
        set { status = newValue.rawValue }
    }
    var displayTitle: String { name.isEmpty ? "Item" : name }

    var known: [String: JSONValue?] {
        ["name": .str(name), "status": .str(status), "askingCents": askingCents > 0 ? .int(askingCents) : nil,
         "soldCents": soldCents > 0 ? .int(soldCents) : nil, "currency": .str(currency), "platform": .text(platform),
         "listingUrl": .text(listingURL), "buyer": .text(buyer), "pickupDate": .day(pickupDate),
         "location": .text(location), "notes": .text(notes)]
    }
    func read(_ d: JSONObject) {
        name = d.str("name"); status = d.str("status", "decide"); askingCents = d.int("askingCents")
        soldCents = d.int("soldCents"); currency = d.str("currency", "EUR"); platform = d.str("platform")
        listingURL = d.str("listingUrl"); buyer = d.str("buyer"); pickupDate = d.day("pickupDate")
        location = d.str("location"); notes = d.str("notes")
    }
}

// MARK: - packing

@Model final class PackingItem: Syncable {
    static var collection: String { "packing" }
    static var typeLabel: String { "Packing item" }
    @Attribute(.unique) var id: String
    var name: String = ""
    var bag: String = Bag.checked.rawValue
    var category: String = ""
    var quantity: Int = 1
    var packed: Bool = false
    var weightGrams: Int = 0
    var notes: String = ""
    var order: Double = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var bagValue: Bag {
        get { Bag(rawValue: bag) ?? .checked }
        set { bag = newValue.rawValue }
    }
    var displayTitle: String { name.isEmpty ? "Item" : name }

    var known: [String: JSONValue?] {
        ["name": .str(name), "bag": .str(bag), "category": .text(category), "quantity": .int(quantity),
         "packed": .flag(packed), "weightGrams": weightGrams > 0 ? .int(weightGrams) : nil,
         "notes": .text(notes), "order": .dbl(order)]
    }
    func read(_ d: JSONObject) {
        name = d.str("name"); bag = d.str("bag", "checked"); category = d.str("category")
        quantity = d.int("quantity", 1); packed = d.bool("packed"); weightGrams = d.int("weightGrams")
        notes = d.str("notes"); order = d.dbl("order")
    }
}

// MARK: - notes (also prayer points: kind "prayer", answeredAt)

@Model final class Note: Syncable {
    static var collection: String { "notes" }
    static var typeLabel: String { "Note" }
    @Attribute(.unique) var id: String
    var title: String = ""
    var body: String = ""
    var area: String = Area.personal.rawValue
    var pinned: Bool = false
    var kind: String = NoteKind.note.rawValue
    var answeredAt: Date? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var kindValue: NoteKind {
        get { NoteKind(rawValue: kind) ?? .note }
        set { kind = newValue.rawValue }
    }
    var areaValue: Area {
        get { Area(rawValue: area) ?? .other }
        set { area = newValue.rawValue }
    }
    var displayTitle: String {
        if !title.isEmpty { return title }
        return body.split(separator: "\n").first.map(String.init) ?? kindValue.title
    }

    var known: [String: JSONValue?] {
        ["title": .str(title), "body": .text(body), "area": .str(area), "pinned": pinned ? .flag(true) : nil,
         "kind": .str(kind), "answeredAt": .day(answeredAt)]
    }
    func read(_ d: JSONObject) {
        title = d.str("title"); body = d.str("body"); area = d.str("area", "personal"); pinned = d.bool("pinned")
        kind = d.str("kind", "note"); answeredAt = d.day("answeredAt")
    }
}

// MARK: - documents (the vault). The file lives at /v1/files/{fileId}.

@Model final class Document: Syncable {
    static var collection: String { "documents" }
    static var typeLabel: String { "Document" }
    @Attribute(.unique) var id: String
    var title: String = ""
    var kind: String = DocumentKind.other.rawValue
    /// A new file gets a new fileId, so other devices know to download it.
    var fileID: String = ""
    var fileName: String = ""
    var mimeType: String = ""
    var sizeBytes: Int = 0
    var sha256: String = ""
    var number: String = ""
    var issuedAt: Date? = nil
    var expiresAt: Date? = nil
    var offline: Bool = true
    var notes: String = ""
    // Local only, never synced: which file this device has, and which it has uploaded.
    var localFileID: String = ""
    var uploadedFileID: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var kindValue: DocumentKind {
        get { DocumentKind(rawValue: kind) ?? .other }
        set { kind = newValue.rawValue }
    }
    var hasFile: Bool { !fileID.isEmpty }
    var displayTitle: String { title.isEmpty ? "Untitled document" : title }

    var known: [String: JSONValue?] {
        ["title": .str(title), "kind": .str(kind), "fileId": .text(fileID), "fileName": .text(fileName),
         "mimeType": .text(mimeType), "sizeBytes": sizeBytes > 0 ? .int(sizeBytes) : nil, "sha256": .text(sha256),
         "number": .text(number), "issuedAt": .day(issuedAt), "expiresAt": .day(expiresAt),
         "offline": .flag(offline), "notes": .text(notes)]
    }
    func read(_ d: JSONObject) {
        title = d.str("title"); kind = d.str("kind", "other"); fileID = d.str("fileId"); fileName = d.str("fileName")
        mimeType = d.str("mimeType"); sizeBytes = d.int("sizeBytes"); sha256 = d.str("sha256"); number = d.str("number")
        issuedAt = d.day("issuedAt"); expiresAt = d.day("expiresAt"); offline = d.bool("offline", true)
        notes = d.str("notes")
    }
}

// MARK: - contacts

@Model final class Contact: Syncable {
    static var collection: String { "contacts" }
    static var typeLabel: String { "Contact" }
    @Attribute(.unique) var id: String
    var name: String = ""
    var role: String = ""
    var organisation: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var displayTitle: String { name.isEmpty ? "New contact" : name }

    var known: [String: JSONValue?] {
        ["name": .str(name), "role": .text(role), "organisation": .text(organisation), "email": .text(email),
         "phone": .text(phone), "address": .text(address), "notes": .text(notes)]
    }
    func read(_ d: JSONObject) {
        name = d.str("name"); role = d.str("role"); organisation = d.str("organisation"); email = d.str("email")
        phone = d.str("phone"); address = d.str("address"); notes = d.str("notes")
    }
}

// MARK: - newsletters

@Model final class Newsletter: Syncable {
    static var collection: String { "newsletters" }
    static var typeLabel: String { "Newsletter" }
    @Attribute(.unique) var id: String
    var title: String = ""
    var number: Int = 0
    var status: String = NewsletterStatus.idea.rawValue
    var plannedDate: Date? = nil
    var sentAt: Date? = nil
    var body: String = ""
    var webURL: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = newID()) { self.id = id }
    var statusValue: NewsletterStatus {
        get { NewsletterStatus(rawValue: status) ?? .idea }
        set { status = newValue.rawValue }
    }
    var displayTitle: String { title.isEmpty ? "Newsletter" : title }

    var known: [String: JSONValue?] {
        ["title": .str(title), "number": number > 0 ? .int(number) : nil, "status": .str(status),
         "plannedDate": .day(plannedDate), "sentAt": .time(sentAt), "body": .text(body), "webUrl": .text(webURL),
         "notes": .text(notes)]
    }
    func read(_ d: JSONObject) {
        title = d.str("title"); number = d.int("number"); status = d.str("status", "idea")
        plannedDate = d.day("plannedDate"); sentAt = d.time("sentAt"); body = d.str("body")
        webURL = d.str("webUrl"); notes = d.str("notes")
    }
}

// MARK: - settings (one shared record; every device uses the same id)

@Model final class MissionSettings: Syncable {
    static var collection: String { "settings" }
    static var typeLabel: String { "Settings" }
    /// uuidv5("settings:main") from server/seed/seed.mjs. Every device must use this id.
    static var mainID: String { "60a98c2f-4004-58e7-bcc2-c88a62377933" }
    @Attribute(.unique) var id: String
    var departureDate: Date = MissionSettings.defaultDeparture
    var supportTargetMonthlyCents: Int = 100_000
    var supportMinimumMonthlyCents: Int = 75_000
    var currency: String = "EUR"
    var nzdPerEur: Double = 1.85
    /// Extra field: average monthly gift, for "partners still needed".
    var averageGiftCents: Int = 2_500
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.distantPast
    var syncedFingerprint: String = ""
    var rawData: Data = Data("{}".utf8)

    init(id: String = MissionSettings.mainID) { self.id = id }
    var displayTitle: String { "Settings" }

    static var defaultDeparture: Date { DayFormat.date("2027-01-05") ?? .now }

    /// The passport must be valid 3 months past the end of the 12-month visa.
    var passportMustLast: Date { Calendar.current.date(byAdding: .month, value: 15, to: departureDate) ?? departureDate }

    var known: [String: JSONValue?] {
        ["key": .str("main"), "departureDate": .day(departureDate),
         "supportTargetMonthlyCents": .int(supportTargetMonthlyCents),
         "supportMinimumMonthlyCents": .int(supportMinimumMonthlyCents), "currency": .str(currency),
         "nzdPerEur": .dbl(nzdPerEur), "averageGiftCents": .int(averageGiftCents)]
    }
    func read(_ d: JSONObject) {
        departureDate = d.day("departureDate") ?? MissionSettings.defaultDeparture
        supportTargetMonthlyCents = d.int("supportTargetMonthlyCents", 100_000)
        supportMinimumMonthlyCents = d.int("supportMinimumMonthlyCents", 75_000)
        currency = d.str("currency", "EUR"); nzdPerEur = d.dbl("nzdPerEur", 1.85)
        averageGiftCents = d.int("averageGiftCents", 2_500)
    }
}

/// Remembers a delete until the server has the tombstone. Never synced itself.
@Model final class Tombstone {
    var id: String
    var collection: String
    var deletedAt: Date
    /// The record's last data, sent along with the delete (the server checks required fields).
    var lastData: Data

    init(id: String, collection: String, lastData: Data) {
        self.id = id
        self.collection = collection
        self.deletedAt = .now
        self.lastData = lastData
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Todo.self, Checklist.self, Partner.self, Gift.self, BudgetEntry.self, SellItem.self, PackingItem.self,
        Note.self, Document.self, Contact.self, Newsletter.self, MissionSettings.self, Tombstone.self,
    ]
}

/// Money is stored in cents, as the contract says.
enum Money {
    static func text(_ cents: Int, _ currency: String = "EUR") -> String {
        (Double(cents) / 100).formatted(.currency(code: currency).precision(.fractionLength(cents % 100 == 0 ? 0 : 2)))
    }
    static func cents(fromEuros euros: Double) -> Int { Int((euros * 100).rounded()) }
    static func euros(_ cents: Int) -> Double { Double(cents) / 100 }
}
