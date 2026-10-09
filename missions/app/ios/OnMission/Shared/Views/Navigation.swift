import SwiftUI
import SwiftData

// MARK: - Which screen each section shows

extension AppSection {
    @ViewBuilder
    var view: some View {
        switch self {
        case .today: TodayView()
        case .tasks: TasksView()
        case .checklists: ChecklistsView()
        case .partners: PartnersView()
        case .documents: VaultView()
        case .budget: BudgetView()
        case .selling: SellView()
        case .packing: PackingView()
        case .prayer: PrayerView()
        case .notes: NotesView()
        case .newsletters: NewslettersView()
        case .contacts: ContactsView()
        case .guides: GuidesView()
        case .search: SearchView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - The "More" tab: folder-tab cards for every other screen

struct MoreView: View {
    @Query private var checklists: [Checklist]
    @Query private var packing: [PackingItem]
    @Query private var budget: [BudgetEntry]
    @Query private var sells: [SellItem]
    @Query private var notes: [Note]
    @Query private var newsletters: [Newsletter]
    @Query private var contacts: [Contact]

    private let columns = [GridItem(.flexible(), spacing: Metrics.l), GridItem(.flexible(), spacing: Metrics.l)]
    private let sections: [AppSection] = [.checklists, .packing, .budget, .selling, .prayer, .notes,
                                          .newsletters, .contacts, .guides, .search, .settings]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Metrics.xl) {
                ForEach(sections) { s in
                    NavigationLink { s.view } label: {
                        FolderTabCard(title: s.title, accent: s.accent, symbol: s.symbol,
                                      count: count(for: s).value, subtitle: count(for: s).label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Metrics.l)
            .padding(.trailing, Metrics.shadow)

            SyncBadge()
                .padding(.horizontal, Metrics.l)
                .padding(.bottom, Metrics.xl)
        }
        .brutalBackground()
        .navigationTitle("More")
    }

    private func count(for s: AppSection) -> (value: String, label: String) {
        switch s {
        case .checklists:
            return (value: "\(checklists.filter { !$0.archived }.count)", label: "lists")
        case .packing:
            let packed = packing.filter(\.packed).count
            return (value: "\(packed)/\(packing.count)", label: "packed")
        case .budget:
            return (value: "\(budget.count)", label: "budget lines")
        case .selling:
            let open = sells.filter { !$0.statusValue.isSettled }.count
            return (value: "\(open)", label: "still to sort")
        case .prayer:
            let open = notes.filter { $0.kindValue == .prayer && $0.answeredAt == nil }.count
            return (value: "\(open)", label: "open points")
        case .notes:
            return (value: "\(notes.filter { $0.kindValue != .prayer }.count)", label: "notes")
        case .newsletters:
            let sent = newsletters.filter { $0.statusValue == .sent }.count
            return (value: "\(newsletters.count)", label: "\(sent) sent")
        case .contacts:
            return (value: "\(contacts.count)", label: "people and offices")
        case .guides:
            return (value: "\(GuidesView.guides.count)", label: "to read")
        case .search:
            return (value: "", label: "Find anything")
        case .settings:
            return (value: "", label: "Sync, backup, mission")
        default:
            return (value: "", label: "")
        }
    }
}

// MARK: - Sync status line

struct SyncBadge: View {
    @Environment(\.modelContext) private var ctx
    @MainActor private var sync: SyncEngine { SyncEngine.shared }

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(statusText)
                .font(Typeface.body(13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
            if sync.isLoggedIn && !sync.isSyncing {
                IconButton(symbol: "arrow.triangle.2.circlepath", size: 32, label: "Sync now") {
                    Task { await sync.sync(ctx) }
                }
            }
        }
        .padding(10)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }

    @MainActor @ViewBuilder
    private var statusIcon: some View {
        if sync.isSyncing {
            BrutalSpinner(size: 16)
        } else if !sync.isLoggedIn {
            Image(systemName: "icloud.slash").foregroundStyle(Palette.muted)
        } else if sync.lastError != nil {
            Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(Palette.danger)
        } else {
            Image(systemName: "checkmark.icloud.fill").foregroundStyle(Palette.ok)
        }
    }

    @MainActor private var statusText: String {
        if sync.isSyncing { return "Syncing…" }
        if !sync.isLoggedIn { return "Only on this device. Sign in under Settings to sync." }
        if let error = sync.lastError { return error }
        if let last = sync.lastSync { return "Synced \(last.formatted(.relative(presentation: .named)))" }
        return "Not synced yet"
    }
}

// MARK: - Opening any record

/// One line for a record in search results and link lists.
struct RecordRow: View {
    let record: AnyRecord
    var showType: Bool = true

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: record.symbol, accent: record.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                if !record.subtitle.isEmpty {
                    Text(record.subtitle)
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if showType {
                Chip(text: record.typeLabel, accent: record.accent)
            }
        }
    }
}

/// The detail screen for any record.
struct RecordDestination: View {
    let record: AnyRecord

    init(record: AnyRecord) { self.record = record }

    var body: some View {
        switch record {
        case .task(let x): TaskDetail(task: x)
        case .checklist(let x): ChecklistDetail(list: x)
        case .partner(let x): PartnerDetail(partner: x)
        case .gift(let x): GiftDetail(gift: x)
        case .budget(let x): BudgetEntryDetail(entry: x)
        case .sell(let x): SellDetail(item: x)
        case .packing(let x): PackingDetail(item: x)
        case .note(let x):
            if x.kindValue == .prayer { PrayerDetail(note: x) } else { NoteDetail(note: x) }
        case .document(let x): DocumentDetail(doc: x)
        case .contact(let x): ContactDetail(contact: x)
        case .newsletter(let x): NewsletterDetail(letter: x)
        }
    }
}

// MARK: - Smart links, on every detail screen (a Form section)

struct LinksSection: View {
    @Environment(\.modelContext) private var ctx
    let record: AnyRecord
    @State private var picking = false
    /// Bumped after linking or unlinking so the list re-reads.
    @State private var tick = 0

    init(record: AnyRecord) { self.record = record }

    var body: some View {
        let _ = tick
        let linked = Links.linked(to: record, ctx)
        Section {
            ForEach(linked) { rec in
                NavigationLink { RecordDestination(record: rec) } label: { RecordRow(record: rec) }
                    .swipeActions {
                        Button("Unlink", role: .destructive) { unlink(rec) }
                    }
                    .contextMenu {
                        Button("Remove link", role: .destructive) { unlink(rec) }
                    }
            }
            Button {
                picking = true
            } label: {
                Label("Link to…", systemImage: "link.badge.plus")
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
        } header: {
            FormHeader("Linked")
        } footer: {
            Text("Connect tasks, partners, documents and notes so the right thing is one tap away.")
        }
        .sheet(isPresented: $picking, onDismiss: { tick += 1 }) {
            LinkPicker(from: record)
        }
    }

    private func unlink(_ other: AnyRecord) {
        Links.unlink(record, other, ctx)
        tick += 1
    }
}

struct LinkPicker: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let from: AnyRecord
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { rec in
                    Button {
                        Links.link(from, rec, ctx)
                        dismiss()
                    } label: {
                        RecordRow(record: rec)
                            .padding(10)
                            .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
                    }
                    .buttonStyle(.plain)
                    .brutalRow(top: 4, bottom: 6)
                }
            }
            .brutalList()
            .brutalSearch(text: $query, prompt: "Find a task, partner, document…")
            .navigationTitle("Link to")
            .navigationBarTitleDisplayMode(.inline)
            .brutalSheetToolbar(cancel: { dismiss() })
        }
        .tint(Palette.ink)
    }

    private var results: [AnyRecord] {
        let already = Set(Links.linked(to: from, ctx).map(\.id))
        let all = AnyRecord.everything(ctx).filter { $0.id != from.id && !already.contains($0.id) }
        let shown = query.isEmpty ? all : all.filter { $0.searchText.localizedCaseInsensitiveContains(query) }
        return Array(shown.prefix(200))
    }
}
