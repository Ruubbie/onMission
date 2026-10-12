import SwiftUI
import SwiftData
import Observation

// MARK: - What a typed line can become

/// The kinds of record the Capture sheet can add.
enum CaptureKind: String, CaseIterable, Identifiable {
    case task, partner, prayer, thanks, sell, packing, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: "Task"
        case .partner: "Person"
        case .prayer: "Prayer"
        case .thanks: "Thanks"
        case .sell: "To sell"
        case .packing: "Packing"
        case .note: "Note"
        }
    }

    /// The line drawing at the top of Capture.
    var art: Drawing {
        switch self {
        case .task: Art.captureTask
        case .partner: Art.capturePerson
        case .prayer: Art.captureFlame
        case .thanks: Art.captureHeart
        case .sell: Art.captureTag
        case .packing: Art.captureBag
        case .note: Art.captureNote
        }
    }

    /// "↓ sounds like a person".
    var noun: String {
        switch self {
        case .task: "a task"
        case .partner: "a person"
        case .prayer: "a prayer"
        case .thanks: "a thank-you"
        case .sell: "something to sell"
        case .packing: "something to pack"
        case .note: "a note"
        }
    }

    /// The tab whose icon pops when something of this kind is added.
    var tab: RootTab {
        switch self {
        case .task: .tasks
        case .partner: .people
        case .prayer, .thanks: .prayer
        case .sell, .packing, .note: .move
        }
    }

    /// Where it went, for the toast.
    var place: String {
        switch self {
        case .task: "Tasks"
        case .partner: "People"
        case .prayer: "Prayer"
        case .thanks: "Prayer & thanks"
        case .sell: "Selling"
        case .packing: "Packing"
        case .note: "Notes"
        }
    }

    /// What the big entry says before you type.
    var placeholder: String {
        switch self {
        case .task: "What needs doing?"
        case .partner: "Who should hear about it?"
        case .prayer: "What to pray for?"
        case .thanks: "What are you thankful for?"
        case .sell: "What's going? Bike 150"
        case .packing: "What goes in the bag?"
        case .note: "What's on your mind?"
        }
    }

    var prompt: String {
        switch self {
        case .task: "Call Anna friday #support"
        case .partner: "Name of someone to ask"
        case .prayer: "Something to pray about"
        case .thanks: "Something you're thankful for"
        case .sell: "Bike 150"
        case .packing: "Charger"
        case .note: "An idea or something to remember"
        }
    }

    /// Words that pick this kind when a line starts with them, like "pray: …" (English and Dutch).
    var prefixes: [String] {
        switch self {
        case .task: ["task", "todo", "taak"]
        case .partner: ["partner", "person", "persoon"]
        case .prayer: ["pray", "prayer", "bid", "gebed"]
        case .thanks: ["thanks", "thank", "dank"]
        case .sell: ["sell", "verkoop", "verkopen"]
        case .packing: ["pack", "inpakken"]
        case .note: ["note", "idea", "notitie", "idee"]
        }
    }
}

enum Capture {
    struct Line {
        /// Named by the line itself ("pray: …", "@Anna"), or nil.
        var kind: CaptureKind?
        var text: String
    }

    /// Splits "pray: for the visa" into .prayer and "for the visa"; "@Anna Jansen" is a person.
    static func split(_ input: String) -> Line {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return Line(kind: .partner, text: String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        if let colon = trimmed.firstIndex(of: ":") {
            let head = String(trimmed[..<colon]).lowercased().trimmingCharacters(in: .whitespaces)
            if let kind = CaptureKind.allCases.first(where: { $0.prefixes.contains(head) }) {
                let rest = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                return Line(kind: kind, text: rest)
            }
        }
        return Line(kind: nil, text: trimmed)
    }

    /// Adds the record and links it to `record` (the screen it was captured on), if any.
    @discardableResult
    static func save(_ text: String, as kind: CaptureKind, linkTo record: AnyRecord?, _ ctx: ModelContext) -> AnyRecord? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let result: AnyRecord
        switch kind {
        case .task:
            let parsed = QuickAdd.parse(text)
            guard !parsed.title.isEmpty else { return nil }
            let t = Automations.addTask(parsed.title, due: parsed.due, for: record,
                                        area: parsed.area ?? defaultArea(for: record), ctx)
            if let p = parsed.priority { t.priorityValue = p }
            return .task(t)
        case .partner:
            let p = Partner()
            p.name = text
            ctx.insert(p)
            result = .partner(p)
        case .prayer:
            let n = Note()
            n.kindValue = .prayer
            n.title = text
            n.areaValue = .personal
            ctx.insert(n)
            result = .note(n)
        case .thanks:
            result = .note(Note.addThanks(text, ctx))
        case .sell:
            guard let item = SellItem.quick(text, ctx) else { return nil }
            result = .sell(item)
        case .packing:
            let item = PackingItem()
            item.name = text
            item.order = (Store.all(PackingItem.self, ctx).map(\.order).max() ?? 0) + 1
            ctx.insert(item)
            result = .packing(item)
        case .note:
            let n = Note()
            n.kindValue = .note
            n.title = text
            ctx.insert(n)
            result = .note(n)
        }
        if let record { Links.link(result, record, ctx) }
        return result
    }

    private static func defaultArea(for record: AnyRecord?) -> Area {
        guard let record else { return .other }
        return switch record {
        case .partner, .gift: .support
        case .checklist(let c): c.areaValue
        case .newsletter: .newsletter
        case .document: .admin
        case .sell: .selling
        case .packing: .packing
        default: .other
        }
    }
}

extension AnyRecord {
    /// Deletes the record the way every screen does (tombstone, links removed).
    func delete(_ ctx: ModelContext) {
        switch self {
        case .task(let x): Store.delete(x, in: ctx)
        case .checklist(let x): Store.delete(x, in: ctx)
        case .partner(let x): Store.delete(x, in: ctx)
        case .gift(let x): Store.delete(x, in: ctx)
        case .budget(let x): Store.delete(x, in: ctx)
        case .sell(let x): Store.delete(x, in: ctx)
        case .packing(let x): Store.delete(x, in: ctx)
        case .note(let x): Store.delete(x, in: ctx)
        case .document(let x): Store.delete(x, in: ctx)
        case .contact(let x): Store.delete(x, in: ctx)
        case .newsletter(let x): Store.delete(x, in: ctx)
        }
    }
}

// MARK: - Which kind the + offers, per screen

/// What the screen on top offers to the + button: a kind, and a record to link new things to.
struct CaptureContext: Equatable {
    var kind: CaptureKind
    var link: AnyRecord? = nil

    static func == (a: CaptureContext, b: CaptureContext) -> Bool {
        a.kind == b.kind && a.link?.id == b.link?.id
    }
}

/// Screens register their context when they appear; the last one on each tab wins.
@MainActor @Observable final class CaptureCenter {
    private struct Entry {
        let id: UUID
        let context: CaptureContext
    }

    private var entries: [RootTab: [Entry]] = [:]

    func context(for tab: RootTab) -> CaptureContext? { entries[tab]?.last?.context }

    func push(_ context: CaptureContext, id: UUID, tab: RootTab) {
        var list = entries[tab] ?? []
        list.removeAll { $0.id == id }
        list.append(Entry(id: id, context: context))
        entries[tab] = list
    }

    func remove(id: UUID, tab: RootTab) {
        entries[tab]?.removeAll { $0.id == id }
    }
}

private struct CaptureContextModifier: ViewModifier {
    @Environment(CaptureCenter.self) private var center
    @Environment(\.rootTab) private var tab
    let context: CaptureContext
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { center.push(context, id: id, tab: tab) }
            .onDisappear { center.remove(id: id, tab: tab) }
            .onChange(of: context) { _, new in center.push(new, id: id, tab: tab) }
    }
}

extension View {
    /// The + on this screen adds this kind, linked to `record` when given.
    func captureContext(_ kind: CaptureKind, linkTo record: AnyRecord? = nil) -> some View {
        modifier(CaptureContextModifier(context: CaptureContext(kind: kind, link: record)))
    }
}


// MARK: - The cover

/// Add anything (handoff §6): a cream cover floods out of the + and folds back into it. What you type
/// decides what it becomes ("pray: …", "sell: Bike 150", "@Anna", or a task like "Call Anna friday #support");
/// the chips override it. Matching records show below, so a name you type opens the person instead of
/// adding them twice.
struct CaptureCover: View {
    @Environment(Router.self) private var router
    @Environment(CaptureCenter.self) private var center
    @Environment(\.chrome) private var chrome
    @State private var session = 0
    @State private var mounted = false

    var body: some View {
        let open = router.captureOpen
        let origin = CGPoint(x: chrome.width - 18 - 22, y: chrome.top - 3 + Metrics.topBar / 2)
        ZStack {
            if mounted {
                CaptureForm(context: center.context(for: router.tab), open: open)
                    .id(session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream.ignoresSafeArea())
        .mask {
            RevealShape(center: origin, progress: open ? 1 : 0)
                .animation(Motion.flood.rm, value: open)
                .ignoresSafeArea()
        }
        .allowsHitTesting(open)
        .accessibilityHidden(!open)
        .accessibilityAddTraits(open ? .isModal : [])
        .onChange(of: open) { _, now in
            if now {
                session += 1
                mounted = true
            } else {
                Motion.after(0.7, always: true) {
                    if !router.captureOpen { mounted = false }
                }
            }
        }
        .zIndex(15)
    }
}

private struct CaptureForm: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    let context: CaptureContext?
    let open: Bool

    @State private var text = ""
    @State private var picked: CaptureKind?
    @State private var artPlay = 0
    @State private var addPlay = 0
    @FocusState private var focused: Bool

    private var line: Capture.Line { Capture.split(text) }
    private var kind: CaptureKind { line.kind ?? picked ?? context?.kind ?? .task }
    /// The typed line picked the kind on its own ("pray: …", "@Anna").
    private var guessed: Bool { line.kind != nil }

    var body: some View {
        let found = matches
        let kinds = CaptureKind.allCases.map { Pills<CaptureKind>.Item(value: $0, title: $0.title) }
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Add anything")
                        .type(.kicker)
                        .frame(height: Metrics.topBar)
                        .padding(.leading, Metrics.gutter - Metrics.sheetSide)
                        .padding(.top, chrome.top - 3)
                        .accessibilityAddTraits(.isHeader)
                    LineArt(drawing: kind.art, ink: .onCream, delay: 0, trigger: artPlay, drawDuration: 0.65, stagger: 0.05)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    entry
                    Hand("↓ sounds like \(kind.noun)", size: 26, tilt: -4)
                        .foregroundStyle(Palette.tomato)
                        .opacity(guessed ? 1 : 0)
                        .animation(.easeOut(duration: 0.35), value: guessed)
                        .padding(.leading, 72)
                        .accessibilityHidden(!guessed)
                    Pills(items: kinds, selection: Binding(get: { kind }, set: pick))
                        .padding(.top, 6)
                    fieldRow
                    if !found.isEmpty {
                        matchesSection(found)
                    } else if text.isEmpty {
                        hints
                    }
                }
                .padding(.horizontal, Metrics.sheetSide)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            addButton
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
                .padding(.bottom, router.keyboardShown ? 10 : max(chrome.bottomSafe, 16) + 6)
        }
        .foregroundStyle(Palette.ink)
        .sensoryFeedback(.success, trigger: addPlay)
        .onAppear {
            guard open else { return }
            Motion.after(0.2) { artPlay += 1 }
            Motion.after(0.4, always: true) { focused = true }
        }
        .onChange(of: open) { _, now in
            if !now { focused = false }
        }
        .onChange(of: kind) { _, _ in artPlay += 1 }
    }

    // MARK: Pieces

    private var entry: some View {
        TextField("", text: $text, prompt: Text(kind.placeholder).foregroundStyle(Palette.ink.opacity(0.3)), axis: .vertical)
            .type(.entry)
            .foregroundStyle(Palette.ink)
            .lineLimit(1...4)
            .focused($focused)
            .submitLabel(.done)
            .padding(.horizontal, 4)
            .padding(.top, 14)
            .frame(minHeight: 76, alignment: .top)
            .onChange(of: text) { _, new in
                // Return adds (the field grows over several lines, so Return arrives as a newline).
                guard new.contains("\n") else { return }
                text = new.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                add()
            }
            .accessibilityLabel("Add or find")
    }

    private func pick(_ k: CaptureKind) {
        picked = k
        // A typed "pray:" would win over the chip, so drop it.
        if line.kind != nil { text = line.text }
    }

    /// One line about where it goes: the due date, the stage, the price, or what it's linked to.
    private var field: (label: String, value: String) {
        if let link = context?.link { return ("Link to", link.title) }
        switch kind {
        case .task:
            let parsed = QuickAdd.parse(line.text)
            let parts = [parsed.due.map { shortDate($0) }, parsed.area?.title, parsed.priority == .high ? "High" : nil]
                .compactMap { $0 }
            return ("Due", parts.isEmpty ? "No date" : parts.joined(separator: " · "))
        case .partner:
            return ("Stage", PartnerStage.idea.title)
        case .prayer, .thanks, .packing:
            return ("Goes to", kind.place)
        case .sell:
            let words = line.text.split(separator: " ")
            if words.count > 1, let last = words.last,
               let price = Double(last.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: ",", with: ".")) {
                return ("Asking", euros(Money.cents(fromEuros: price)))
            }
            return ("Asking", "Price later")
        case .note:
            return ("Link to", "Nothing yet")
        }
    }

    private var fieldRow: some View {
        let f = field
        return HStack(spacing: 12) {
            Text(f.label).type(TypeStyle(size: 15.5, wght: 600, relativeTo: .body)).opacity(0.6)
            Spacer(minLength: 8)
            Text(f.value)
                .type(TypeStyle(size: 15.5, wght: 800, relativeTo: .body))
                .foregroundStyle(Palette.tomatoInk)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .frame(minHeight: 54)
        .overlay(alignment: .top) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        .padding(.horizontal, 4)
        .padding(.top, 14)
        .animation(.easeOut(duration: 0.2), value: f.value)
        .accessibilityElement(children: .combine)
    }

    private func matchesSection(_ found: [AnyRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Already here", count: found.count).padding(.top, 22)
            ForEach(Array(found.enumerated()), id: \.element.id) { index, rec in
                Button { open(rec) } label: {
                    RecordRow(record: rec, rule: index < found.count - 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionHeader("Type it like you'd say it").padding(.bottom, 4)
            hint("Call Anna friday #support", "a task with a date")
            hint("@Anna Jansen", "a new person")
            hint("pray: the visa interview", "a prayer")
            hint("thanks: coffee with Jan", "a thank-you")
            hint("sell: Bike 150", "something to sell")
            hint("pack: charger", "something to pack")
        }
        .padding(.top, 22)
        .padding(.horizontal, 4)
    }

    private func hint(_ example: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(example).type(.bodyBold)
            Text(meaning).type(.small).foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private var addTitle: String {
        switch kind {
        case .task: "Add task"
        case .partner: "Add person"
        case .prayer: "Add prayer"
        case .thanks: "Add thanks"
        case .sell: "Add to Selling"
        case .packing: "Add to Packing"
        case .note: "Add note"
        }
    }

    private var addButton: some View {
        let empty = line.text.isEmpty
        return Button(action: add) {
            HStack(spacing: 10) {
                Text(addTitle)
                AnimatedIcon(.arrow, size: 19, trigger: addPlay)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(CapsuleStyle(kind: .filled, wide: true))
        .disabled(empty)
        .opacity(empty ? 0.45 : 1)
        .animation(.easeOut(duration: 0.2), value: empty)
    }

    // MARK: Data

    private var matches: [AnyRecord] {
        let q = line.text
        guard q.count >= 2 else { return [] }
        return Array(AnyRecord.everything(ctx).filter { $0.searchText.localizedCaseInsensitiveContains(q) }.prefix(5))
    }

    /// Adds it, folds the cover back into the +, then says where it went and pops that tab's icon.
    private func add() {
        let k = kind
        guard let rec = Capture.save(line.text, as: k, linkTo: context?.link, ctx) else { return }
        addPlay += 1
        focused = false
        let message = k == .partner ? "\(rec.title) added to People" : "Added to \(k.place)"
        router.captureOpen = false
        Motion.after(0.42) {
            router.showToast(message)
            router.popIcon(k.tab)
        }
    }

    private func open(_ rec: AnyRecord) {
        focused = false
        router.captureOpen = false
        Motion.after(0.3) { router.open(rec) }
    }
}
