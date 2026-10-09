# Internal interfaces (for the two people/agents building the app in parallel)

Model layer is fixed: Shared/Model/{JSON,Models,Enums}.swift, Shared/Design/Tokens.swift, Shared/App/AppSection.swift.
Read them first. Do not rename anything in them; if something must change, note it at the bottom of this file.

## Logic + sync layer (worker A) provides

```swift
enum Store {
  static func all<T: Syncable>(_ type: T.Type, _ ctx: ModelContext) -> [T]
  static func find<T: Syncable>(_ type: T.Type, id: String, _ ctx: ModelContext) -> T?
  static func settings(_ ctx: ModelContext) -> MissionSettings          // creates the main record if missing
  static func delete<T: Syncable>(_ item: T, in ctx: ModelContext)      // tombstone + remove links pointing at it
}

enum AnyRecord: Identifiable {   // every user-facing record type (not settings)
  case task(Todo), checklist(Checklist), partner(Partner), gift(Gift), budget(BudgetEntry), sell(SellItem)
  case packing(PackingItem), note(Note), document(Document), contact(Contact), newsletter(Newsletter)
  init?(_ model: any Syncable)
  var model: any Syncable
  var id: String          // "tasks/<uuid>" (same as RecordLink.key)
  var title: String; var subtitle: String; var symbol: String; var accent: Accent; var typeLabel: String
  var searchText: String  // title + notes/body/etc. for search
  static func everything(_ ctx: ModelContext) -> [AnyRecord]
  static func resolve(_ link: RecordLink, _ ctx: ModelContext) -> AnyRecord?
}

enum Links {   // smart links, stored in data.links, shown in both directions
  static func link(_ a: AnyRecord, _ b: AnyRecord, _ ctx: ModelContext)
  static func unlink(_ a: AnyRecord, _ b: AnyRecord, _ ctx: ModelContext)
  static func linked(to r: AnyRecord, _ ctx: ModelContext) -> [AnyRecord]
}

@MainActor @Observable final class SyncEngine {
  static let shared: SyncEngine
  var serverURL: String; var email: String
  var isLoggedIn: Bool; var isSyncing: Bool; var lastSync: Date?; var lastError: String?
  func login(server: String, email: String, password: String) async throws
  func logout() async
  func sync(_ ctx: ModelContext) async
  func testConnection() async -> String
  func devices() async throws -> [API.Device]          // API.Device: id, name, platform, lastSeenAt: Date?, current: Bool
  func revokeDevice(_ id: String) async throws
}

enum DocumentFiles {
  static func localURL(_ d: Document) -> URL?          // nil if this device doesn't have the file
  static func attach(from url: URL, to d: Document) throws
  static func attach(data: Data, name: String, to d: Document) throws
  static func detach(_ d: Document)
  static func download(_ d: Document) async throws     // on demand, for documents with offline == false
  static func sizeText(_ d: Document) -> String
}

struct Insights {
  init(settings: MissionSettings, tasks: [Todo], partners: [Partner], gifts: [Gift], budget: [BudgetEntry],
       sells: [SellItem], packing: [PackingItem], documents: [Document])
  var daysToGo: Int
  var committedMonthlyCents: Int; var monthlyPartners: Int; var supportProgress: Double   // 0...1 of target
  var stillNeededForMinimumCents: Int; var partnersStillNeeded: Int; var openConversations: Int
  var giftsThisMonthCents: Int; var oneOffGiftCents: Int
  var followUps: [Partner]; var toThank: [Partner]
  var overdue: [Todo]; var thisWeek: [Todo]; var openTasks: Int; var tasksDone: Int; var taskProgress: Double
  var monthlyBudgetCents: Int; var setupBudgetCents: Int; var setupPaidCents: Int     // all in EUR (NZD converted)
  var soldCents: Int; var sellPotentialCents: Int; var itemsToSort: Int
  var setupCoveredCents: Int; var setupGapCents: Int
  var packed: Int; var packingTotal: Int; var documentsMissingFile: Int
  struct Warning: Identifiable { let id: String; let text: String; let record: AnyRecord? }
  var warnings: [Warning]
  static func byDue(_ a: Todo, _ b: Todo) -> Bool
  static func eurCents(_ cents: Int, _ currency: String, _ s: MissionSettings) -> Int
}

enum Automations {
  static func partnerStageChanged(_ p: Partner, from old: PartnerStage, _ ctx: ModelContext)
  static func partnerThanked(_ p: Partner, _ ctx: ModelContext)
  static func taskDone(_ t: Todo, _ ctx: ModelContext)
  @discardableResult static func addTask(_ title: String, due: Date?, for record: AnyRecord? = nil,
       area: Area = .other, _ ctx: ModelContext, notes: String = "") -> Todo
  @discardableResult static func recordGift(for p: Partner, cents: Int, recurring: Bool, _ ctx: ModelContext) -> Gift
}
enum QuickAdd { struct Parsed { var title: String; var due: Date?; var area: Area?; var priority: Priority? }
                static func parse(_ s: String) -> Parsed }
enum MessageTemplate: CaseIterable, Identifiable { var title: String; func text(for p: Partner) -> String
                static func suggested(for p: Partner) -> [MessageTemplate] }
enum Reminders { static func requestPermission() async -> Bool; static func isAuthorized() async -> Bool
                 @MainActor static func refresh(_ ctx: ModelContext) async }
enum Seeder { static func seedIfNeeded(_ ctx: ModelContext) }     // Resources/seed-records.json
enum Backup { static func export(_ ctx: ModelContext) -> Data; static func restore(_ data: Data, _ ctx: ModelContext) throws -> Int
              static func partnersCSV(_ p: [Partner]) -> Data; static func importPartners(_ text: String, _ ctx: ModelContext) -> Int }
struct DataFile: FileDocument { init(data: Data) }
```

## UI layer (worker B) provides

Shared/Design/Components.swift (the brutal components), Shared/App/OnMissionApp.swift (app, font registration, RootView),
Shared/Views/*.swift (every screen), `extension AppSection { @ViewBuilder var view: some View }`,
`struct RecordDestination: View { init(record: AnyRecord) }`, `struct LinksSection: View { init(record: AnyRecord) }`.

## Notes / requested changes

- (worker A, logic + sync) No model changes needed. Small additions on top of the list above, all optional for the UI:
  `SyncEngine.revision: Int` (bumps after every sync), `SyncEngine.api: API?`, `SyncEngine.deviceInfo`;
  `DocumentFiles.download` is `@MainActor` (call it from a view's `Task {}`); `DocumentFiles.fileURL/removeLocal/sha256/mimeType`;
  `API.Failure` (LocalizedError) is what `login`, `devices` and `revokeDevice` throw; `Store.pendingDeletes`;
  `Registry` / `RecordKind` (one entry per collection, used by sync, seed and backup); `MessageTemplate` has String raw values.
  Wire format checked against the real server with `node tools/contract-check.mjs` (see the file header).
