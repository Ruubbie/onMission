import SwiftUI
import SwiftData

// MARK: - Move (handoff §5): how ready you are, and a tile for everything about leaving

/// How ready you are to go: the average of checklist items ticked, papers in the vault and things packed.
/// Parts with nothing in them yet don't count.
enum Readiness {
    static func fraction(tasks: [Todo], documents: [Document], packing: [PackingItem]) -> Double {
        let items = tasks.filter { !$0.checklistID.isEmpty }
        var parts: [Double] = []
        if !items.isEmpty { parts.append(Double(items.filter(\.isDone).count) / Double(items.count)) }
        if !documents.isEmpty { parts.append(Double(documents.filter(\.hasFile).count) / Double(documents.count)) }
        if !packing.isEmpty { parts.append(Double(packing.filter(\.packed).count) / Double(packing.count)) }
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) / Double(parts.count)
    }
}

extension Document {
    /// Expires within 90 days (or already has).
    static func expiresSoon(_ d: Date) -> Bool {
        d < (Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .now)
    }
}

struct MoveView: View {
    struct Status {
        let text: String
        var alert: Bool = false
    }

    enum Hub: CaseIterable {
        case checklists, vault, packing, budget, selling, newsletters, notes, guides

        var title: String {
            switch self {
            case .checklists: "Checklists"
            case .vault: "Vault"
            case .packing: "Packing"
            case .budget: "Budget"
            case .selling: "Selling"
            case .newsletters: "Newsletters"
            case .notes: "Notes"
            case .guides: "Guides"
            }
        }

        var icon: Icon {
            switch self {
            case .checklists: .list
            case .vault: .lock
            case .packing: .bag
            case .budget: .euro
            case .selling: .tag
            case .newsletters: .mail
            case .notes: .note
            case .guides: .book
            }
        }

        var page: Page {
            switch self {
            case .checklists: .checklists
            case .vault: .vault
            case .packing: .packing
            case .budget: .budget
            case .selling: .selling
            case .newsletters: .newsletters
            case .notes: .notes
            case .guides: .guides
            }
        }
    }

    @Environment(Router.self) private var router
    @Environment(\.entry) private var entry
    @Query private var tasks: [Todo]
    @Query private var packing: [PackingItem]
    @Query private var budget: [BudgetEntry]
    @Query private var sells: [SellItem]
    @Query private var notes: [Note]
    @Query private var newsletters: [Newsletter]
    @Query private var documents: [Document]
    @Query private var settingsList: [MissionSettings]
    @State private var tilePlay = Array(repeating: 0, count: Hub.allCases.count)

    /// The home-screen name (brand.appName in tokens.json, set by CI).
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "hesent.me"
    }

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: [], partners: [], gifts: [], budget: budget, sells: sells,
                 packing: packing, documents: documents)
    }

    var body: some View {
        let ready = Readiness.fraction(tasks: tasks, documents: documents, packing: packing)
        let pct = Int((ready * 100).rounded())
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Leaving \(settings.departureDate.formatted(.dateTime.day().month(.wide)))", size: 33).rise(0).at(24, 106)
            CountUp(value: pct, trigger: entry, duration: 1.4) { "\($0)%" }
                .type(.disp(124))
                .lineLimit(1)
                .offset(y: FontMetrics.shift(.archivo, size: 124, lineHeight: 0.88))
                .rise(1)
                .at(18, 140)
            CapLine("Ready\nto go").rise(2).at(238, 192)
            ArcArt(fraction: ready, trigger: entry, from: "AMS", to: airport).at(0, 236)
        } sheet: {
            SheetScroll {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                    ForEach(Array(Hub.allCases.enumerated()), id: \.offset) { index, hub in
                        let s = status(for: hub)
                        Tile(icon: hub.icon, title: hub.title, status: s.text, alert: s.alert, trigger: tilePlay[index]) {
                            router.push(hub.page)
                        }
                        .rise(index)
                    }
                }
                MoreLink(title: "Find anything") { router.push(.search) }
            }
        }
        .onAppear(perform: playTiles)
        .onChange(of: entry) { _, _ in playTiles() }
        .captureContext(.task)
    }

    /// The tile icons play one after another (from 260ms, 70ms apart).
    private func playTiles() {
        guard !Motion.reduced else { return }
        for i in tilePlay.indices {
            Motion.after(0.26 + Double(i) * 0.07) { tilePlay[i] += 1 }
        }
    }

    /// "ZQN" for Queenstown; otherwise the first three letters of the city.
    private var airport: String {
        let city = settings.city
        if city.localizedCaseInsensitiveContains("queenstown") { return "ZQN" }
        return String(city.filter(\.isLetter).prefix(3)).uppercased()
    }

    private func status(for hub: Hub) -> Status {
        switch hub {
        case .checklists:
            let items = tasks.filter { !$0.checklistID.isEmpty }
            let left = items.filter { !$0.isDone }.count
            if items.isEmpty { return Status(text: "Start one") }
            return Status(text: left == 0 ? "All done" : "\(left) left")
        case .vault:
            let soon = documents.filter { d in d.expiresAt.map(Document.expiresSoon) ?? false }.count
            let missing = documents.filter { !$0.hasFile }.count
            if missing > 0 { return Status(text: "\(missing) missing", alert: true) }
            if soon > 0 { return Status(text: "\(soon) expiring", alert: true) }
            return Status(text: documents.isEmpty ? "Empty" : "All in")
        case .packing:
            guard !packing.isEmpty else { return Status(text: "Nothing yet") }
            let pct = Int((Double(packing.filter(\.packed).count) / Double(packing.count) * 100).rounded())
            return Status(text: "\(pct)% packed")
        case .budget:
            let gap = insights.setupGapCents
            return gap > 0 ? Status(text: "\(euros(gap)) to go") : Status(text: "On track")
        case .selling:
            let i = insights
            if i.itemsToSort > 0 { return Status(text: "\(i.itemsToSort) to decide") }
            let listed = sells.filter { $0.statusValue == .listed || $0.statusValue == .reserved }.count
            return Status(text: listed > 0 ? "\(listed) listed" : "\(euros(i.soldCents)) sold")
        case .newsletters:
            if let open = newsletters.filter({ $0.statusValue != .sent }).max(by: { $0.number < $1.number }) {
                let month = open.plannedDate.map { $0.formatted(.dateTime.month(.abbreviated)) }
                return Status(text: month.map { "\($0) \(open.statusValue.title.lowercased())" } ?? open.statusValue.title)
            }
            if let last = newsletters.compactMap(\.sentAt).max() { return Status(text: "Sent \(whenText(last))") }
            return Status(text: "None yet")
        case .notes:
            return Status(text: "\(notes.filter { $0.kindValue != .prayer && !$0.isThanks }.count)")
        case .guides:
            let all = GuidesView.guides
            let read = all.filter { LocalState.guideProgress($0.id) >= 1 }.count
            return Status(text: read == 0 ? "\(all.count)" : "\(read) of \(all.count) read")
        }
    }
}

/// The dotted arc from home to there: a plane flies along it to how ready you are (1.6s), turning with the curve.
private struct ArcArt: View {
    let fraction: Double
    let trigger: Int
    let from: String
    let to: String

    var body: some View {
        let path = SVG.path(Art.arcPath)
        ZStack(alignment: .topLeading) {
            LineArt(drawing: Art.arc)
            Clock(trigger: trigger, duration: 1.7) { t in
                let f = max((t >= 1.6 ? 1 : Ease.outCubic(t / 1.6)) * fraction, 0.001)
                let spot = path.point(at: f)
                ZStack(alignment: .topLeading) {
                    SVGShape(d: Art.arcPath)
                        .trim(from: 0, to: f)
                        .stroke(Palette.cream, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                    Plane()
                        .rotationEffect(.degrees(spot.angle))
                        .position(spot.point)
                }
                .frame(width: 390, height: 138, alignment: .topLeading)
            }
            // Under the ends, clear of the plane while it waits at home.
            label(from).position(x: 34, y: 142)
            label(to).position(x: 356, y: 142)
        }
        .frame(width: 390, height: 138, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .type(TypeStyle(size: 12, wght: 800, tracking: 0.125, relativeTo: nil))
            .foregroundStyle(Palette.cream)
            .fixedSize()
    }
}

/// The little plane: a tomato body with a cream outline.
private struct Plane: View {
    var body: some View {
        ZStack {
            SVGShape(d: "M4 1 L38 10 L4 19 L11 10 Z").fill(Palette.tomato)
            SVGShape(d: "M4 1 L38 10 L4 19 L11 10 Z")
                .stroke(Palette.cream, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round, lineJoin: .round))
            SVGShape(d: "M11 10 L38 10")
                .stroke(Palette.cream, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round))
        }
        // Drawn around (20, 10) so it turns about its middle.
        .frame(width: 40, height: 20, alignment: .topLeading)
    }
}

// MARK: - Pages for any record

/// The page for any record.
struct RecordDestination: View {
    let record: AnyRecord

    init(record: AnyRecord) { self.record = record }

    var body: some View {
        switch record {
        case .task(let x): TaskPage(task: x)
        case .checklist(let x): ChecklistDetail(list: x)
        case .partner(let x): PartnerPage(partner: x)
        case .gift(let x): GiftDetail(gift: x)
        case .budget(let x): BudgetEntryDetail(entry: x)
        case .sell(let x): SellDetail(item: x)
        case .packing(let x): PackingDetail(item: x)
        case .note(let x):
            if x.kindValue == .prayer || x.isThanks { PrayerDetail(note: x) } else { NoteDetail(note: x) }
        case .document(let x): DocumentDetail(doc: x)
        case .contact(let x): ContactDetail(contact: x)
        case .newsletter(let x): NewsletterDetail(letter: x)
        }
    }
}

/// A detail page in the house pattern: an aside by hand and the record's name big on tomato,
/// its fields on the sheet (handoff §7, "not in the prototype").
struct DetailPage<Content: View>: View {
    let aside: String
    let title: String
    var cap: String = ""
    @ViewBuilder let content: Content

    init(aside: String, title: String, cap: String = "", @ViewBuilder content: () -> Content) {
        self.aside = aside
        self.title = title
        self.cap = cap
        self.content = content()
    }

    var body: some View {
        let shown = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
        let size: CGFloat = shown.count > 22 ? 52 : (shown.count > 11 ? 68 : 96)
        Screen(posterHeight: 306) {
            Hand(aside).rise(0).at(24, 106)
            VStack(alignment: .leading, spacing: 0) {
                Lines(wrapLines(shown, .disp(size), width: 346, maxLines: 3), .disp(size), lineHeight: 0.9, minScale: 0.6)
                if !cap.isEmpty {
                    CapLine(cap).lineLimit(2).padding(.top, 16).padding(.leading, 2)
                }
            }
            .frame(width: 346, alignment: .leading)
            .rise(1)
            .at(22, 146)
        } sheet: {
            SheetScroll { content }
        }
    }
}

/// A whole cream page (the reader, search, a note): ink on cream, scrolling under the top bar.
struct CreamPage<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.chrome) private var chrome

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, chrome.top + Metrics.topBar + 8)
            .padding(.bottom, chrome.bar + 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riseSheet()
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .top) {
            // The top bar sits on cream; scrolled content passes under it.
            Palette.cream.frame(height: chrome.top + Metrics.topBar).allowsHitTesting(false)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream)
        .foregroundStyle(Palette.ink)
    }
}

/// A sheet for a quick form (record a gift, add names, link to…): Cancel, a tomato title, Save.
struct CreamSheet<Content: View>: View {
    let title: String
    var save: String = "Save"
    var saveDisabled = false
    var onSave: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, save: String = "Save", saveDisabled: Bool = false, onSave: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.save = save
        self.saveDisabled = saveDisabled
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .type(.bodyBold)
                    .foregroundStyle(Palette.tomatoInk)
                    .frame(minHeight: 44)
                Spacer()
                if let onSave {
                    Button(save, action: onSave)
                        .buttonStyle(.filledSmall)
                        .disabled(saveDisabled)
                        .opacity(saveDisabled ? 0.4 : 1)
                }
            }
            .padding(.top, 12)
            Text(title)
                .type(TypeStyle(size: 30, wdth: 78, wght: 800, relativeTo: .title))
                .foregroundStyle(Palette.tomato)
                .lineLimit(2)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, Metrics.sheetSide)
        .background(Palette.cream.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .environment(\.colorScheme, .light)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Metrics.sheetRadius)
    }
}

// MARK: - Opening any record

/// One line for a record in search results and link lists: an avatar for people, a paper box for the rest.
struct RecordRow: View {
    let record: AnyRecord
    var rule = true
    var showType = true

    var body: some View {
        Row(rule: rule) {
            switch record {
            case .partner(let p): Avatar(name: p.displayTitle)
            case .contact(let c): Avatar(name: c.displayTitle)
            default: DocBox(icon: record.icon)
            }
            RowText(title: record.title, subtitle: line)
        }
    }

    private var line: String {
        let sub = record.subtitle
        guard showType else { return sub }
        if sub.isEmpty || sub.hasPrefix(record.typeLabel) { return sub.isEmpty ? record.typeLabel : sub }
        return "\(record.typeLabel) · \(sub)"
    }
}

// MARK: - Smart links, on every detail page

struct LinksBlock: View {
    @Environment(\.modelContext) private var ctx
    let record: AnyRecord
    @State private var picking = false
    /// Bumped after linking or unlinking so the list re-reads.
    @State private var tick = 0

    init(record: AnyRecord) { self.record = record }

    var body: some View {
        let _ = tick
        let linked = Links.linked(to: record, ctx)
        FormBlock("Linked", footer: linked.isEmpty ? "Connect tasks, people, papers and notes so the right thing is one tap away." : "") {
            ForEach(linked) { rec in
                LinkedRow(record: rec)
                    .contextMenu {
                        Button("Remove link", role: .destructive) { unlink(rec) }
                    }
                    .accessibilityAction(named: "Remove link") { unlink(rec) }
            }
            ActionRow(title: "Link to…", icon: .link) { picking = true }
        }
        .sheet(isPresented: $picking, onDismiss: { tick += 1 }) {
            LinkPicker(from: record)
        }
    }

    private func unlink(_ other: AnyRecord) {
        withAnimation(Motion.fold.rm) {
            Links.unlink(record, other, ctx)
            tick += 1
        }
    }
}

struct LinkPicker: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let from: AnyRecord
    @State private var query = ""

    var body: some View {
        let found = results
        CreamSheet(title: "Link to") {
            SearchField(text: $query, prompt: "Find a task, person, paper…")
                .padding(.vertical, 12)
            ForEach(Array(found.enumerated()), id: \.element.id) { index, rec in
                Button {
                    Links.link(from, rec, ctx)
                    dismiss()
                } label: {
                    RecordRow(record: rec, rule: index < found.count - 1)
                }
                .buttonStyle(.plain)
            }
            if found.isEmpty {
                EmptyRow(title: "Nothing found", message: query.isEmpty ? "Add something first." : "No match for \"\(query)\".")
            }
        }
    }

    private var results: [AnyRecord] {
        let already = Set(Links.linked(to: from, ctx).map(\.id))
        let all = AnyRecord.everything(ctx).filter { $0.id != from.id && !already.contains($0.id) }
        let shown = query.isEmpty ? all : all.filter { $0.searchText.localizedCaseInsensitiveContains(query) }
        return Array(shown.prefix(200))
    }
}
