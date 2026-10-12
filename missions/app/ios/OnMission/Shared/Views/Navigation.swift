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
        case .partners: PeopleView()
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

// MARK: - The "Move" tab: everything for leaving, grouped, each with a live line, and search on top

struct MoveView: View {
    struct Status {
        let text: String
        var alert: Bool = false
    }

    @Environment(\.modelContext) private var ctx
    @Query private var checklists: [Checklist]
    @Query private var tasks: [Todo]
    @Query private var packing: [PackingItem]
    @Query private var budget: [BudgetEntry]
    @Query private var sells: [SellItem]
    @Query private var notes: [Note]
    @Query private var newsletters: [Newsletter]
    @Query private var documents: [Document]
    @Query private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var settingsList: [MissionSettings]
    @State private var query = ""

    /// The home-screen name (brand.appName in tokens.json, set by CI).
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "hesent.me"
    }

    private var insights: Insights {
        Insights(settings: settingsList.first ?? MissionSettings(), tasks: [], partners: partners, gifts: gifts,
                 budget: budget, sells: sells, packing: packing, documents: documents)
    }

    private var searching: Bool { query.trimmingCharacters(in: .whitespaces).count >= 2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.l) {
                header
                BrutalSearchField(text: $query, prompt: "Find anything: passport, Anna, bike…")
                if searching {
                    results
                } else {
                    group("Leaving", [.checklists, .documents, .packing])
                    group("Money", [.budget, .selling])
                    group("Words", [.newsletters, .notes, .guides])
                    SyncBadge()
                }
            }
            .padding(.horizontal, Metrics.l)
            .padding(.top, 4)
            .padding(.bottom, Metrics.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .brutalBackground()
        .toolbar(.hidden, for: .navigationBar)
        .captureContext(.task)
    }

    private var header: some View {
        let days = insights.daysToGo
        return HStack(spacing: 10) {
            Ollie(pose: .side, height: 52)
            VStack(alignment: .leading, spacing: 1) {
                Text("Move").font(Typeface.heading(18)).foregroundStyle(Palette.ink)
                Text(days > 0 ? "\(days) days until you leave" : "Kia ora, you're there")
                    .font(Typeface.body(12.5))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            NavigationLink { SettingsView() } label: { IconTile(symbol: "gearshape", size: 40) }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
        }
    }

    private func group(_ title: String, _ sections: [AppSection]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(title)
            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element) { index, s in
                    NavigationLink { s.view } label: { MoveRow(section: s, status: status(for: s)) }
                        .buttonStyle(.plain)
                    if index < sections.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 1).padding(.leading, 58)
                    }
                }
            }
            .brutalBox(radius: 18)
        }
    }

    private var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let found = Array(AnyRecord.everything(ctx).filter { $0.searchText.localizedCaseInsensitiveContains(q) }.prefix(200))
        return VStack(alignment: .leading, spacing: Metrics.s) {
            if found.isEmpty {
                BrutalEmptyState(symbol: "questionmark", title: "Nothing found", message: "No match for \"\(q)\".", accent: .grey)
            } else {
                SectionHeader("Results", count: found.count)
                ForEach(found) { rec in
                    NavigationLink { RecordDestination(record: rec) } label: {
                        RecordRow(record: rec)
                            .padding(Metrics.m)
                            .brutalBox(radius: Metrics.radiusSmall)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func status(for s: AppSection) -> Status {
        switch s {
        case .checklists:
            let items = tasks.filter { !$0.checklistID.isEmpty }
            let lists = checklists.filter { !$0.archived }.count
            return Status(text: "\(items.filter(\.isDone).count) of \(items.count) ticked · \(lists) list\(lists == 1 ? "" : "s")")
        case .documents:
            let soon = documents.filter { d in d.expiresAt.map(DocumentDetail.expiresSoon) ?? false }.count
            let missing = documents.filter { !$0.hasFile }.count
            if soon > 0 { return Status(text: "\(soon) expire\(soon == 1 ? "s" : "") within 90 days", alert: true) }
            if missing > 0 { return Status(text: "\(documents.count) documents · \(missing) without a file", alert: true) }
            return Status(text: "\(documents.count) document\(documents.count == 1 ? "" : "s")")
        case .packing:
            let packed = packing.filter(\.packed).count
            return Status(text: packing.isEmpty ? "Nothing to pack yet" : "\(packed) of \(packing.count) packed")
        case .budget:
            let gap = insights.setupGapCents
            return gap > 0 ? Status(text: "\(euros(gap)) still to cover before you go") : Status(text: "One-off costs covered")
        case .selling:
            let i = insights
            if i.itemsToSort > 0 { return Status(text: "\(i.itemsToSort) to decide · \(euros(i.sellPotentialCents)) to sell") }
            return Status(text: "\(euros(i.soldCents)) sold · \(euros(i.sellPotentialCents)) to go")
        case .newsletters:
            if let open = newsletters.filter({ $0.statusValue != .sent }).max(by: { $0.number < $1.number }) {
                return Status(text: "#\(open.number) is \(open.statusValue.title.lowercased())")
            }
            if let last = newsletters.compactMap(\.sentAt).max() { return Status(text: "Last sent \(shortDate(last))") }
            return Status(text: "None yet")
        case .notes:
            let n = notes.filter { $0.kindValue != .prayer && !$0.isThanks }.count
            return Status(text: "\(n) note\(n == 1 ? "" : "s")")
        case .guides:
            return Status(text: "\(GuidesView.guides.count) guides to read")
        default:
            return Status(text: "")
        }
    }
}

private struct MoveRow: View {
    let section: AppSection
    let status: MoveView.Status

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: section.symbol, accent: section.accent, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(Typeface.body(15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                if !status.text.isEmpty {
                    Text(status.text)
                        .font(Typeface.body(12.5, weight: .semibold))
                        .foregroundStyle(status.alert ? Palette.danger : Palette.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
                .font(Typeface.body(12, weight: .medium))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
            Spacer(minLength: 0)
            if sync.isLoggedIn && !sync.isSyncing {
                IconButton(symbol: "arrow.triangle.2.circlepath", size: 32, label: "Sync now") {
                    Task { await sync.sync(ctx) }
                }
            }
        }
        .padding(10)
        .brutalBox(radius: 16)
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
                            .brutalBox(radius: 16)
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
