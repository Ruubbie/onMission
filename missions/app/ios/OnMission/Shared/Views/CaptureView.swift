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

    var symbol: String {
        switch self {
        case .task: "checkmark.square"
        case .partner: "person.badge.plus"
        case .prayer: "hands.and.sparkles"
        case .thanks: "heart"
        case .sell: "tag"
        case .packing: "suitcase"
        case .note: "note.text"
        }
    }

    var accent: Accent {
        switch self {
        case .task: .yellow
        case .partner: .pink
        case .prayer: .purple
        case .thanks: .sand
        case .sell: .sand
        case .packing: .lime
        case .note: .grey
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
        switch record {
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

// MARK: - The sheet

/// One field to add or find anything. What you type decides what it becomes ("pray: …", "sell: Bike 150",
/// "@Anna", or a task like "Call Anna friday #support"); the chips override it. Matching records show
/// below, so a name you type opens the person instead of adding them twice.
struct CaptureSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let context: CaptureContext?

    @State private var text = ""
    @State private var picked: CaptureKind?
    @State private var added: [AnyRecord] = []
    @FocusState private var focused: Bool

    private var line: Capture.Line { Capture.split(text) }
    private var kind: CaptureKind { line.kind ?? picked ?? context?.kind ?? .task }

    var body: some View {
        let found = matches
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.l) {
                    field
                    kindChips
                    if !line.text.isEmpty { preview }
                    if !found.isEmpty { matchesSection(found) }
                    if !added.isEmpty { addedSection }
                    if text.isEmpty && added.isEmpty { hints }
                }
                .padding(Metrics.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .brutalBackground()
            .navigationTitle("Add or find")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(BrutalButtonStyle(kind: .secondary, compact: true))
                }
            }
            .toolbarBackground(Palette.backgroundTop, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.gradient)
        .onAppear { focused = true }
    }

    // MARK: Pieces

    private var field: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: kind.symbol, accent: kind.accent, size: 34)
                .animation(.easeOut(duration: 0.15), value: kind)
            TextField(kind.prompt, text: $text, prompt: Text(kind.prompt).foregroundStyle(Palette.muted))
                .font(Typeface.body(17))
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(save)
            Button(action: save) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Accent.yellow.color))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(line.text.isEmpty)
            .opacity(line.text.isEmpty ? 0.4 : 1)
            .accessibilityLabel("Add \(kind.title.lowercased())")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .brutalBox(radius: Metrics.radius)
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CaptureKind.allCases) { k in
                    FilterChip(text: k.title, symbol: k.symbol, selected: kind == k) {
                        picked = k
                        // A typed "pray:" would win over the chip, so drop it.
                        if line.kind != nil { text = line.text }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// What pressing return will do, in words.
    private var preview: some View {
        HStack(spacing: 6) {
            ForEach(previewParts, id: \.self) { part in
                Chip(text: part, accent: kind.accent, selected: false)
            }
            if let link = context?.link {
                Chip(text: "Linked to \(link.title)", accent: .grey, symbol: "link", selected: false)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
    }

    private var previewParts: [String] {
        switch kind {
        case .task:
            let parsed = QuickAdd.parse(line.text)
            var parts = ["Task"]
            if let due = parsed.due { parts.append(shortDate(due)) }
            if let area = parsed.area { parts.append(area.title) }
            if parsed.priority == .high { parts.append("High") }
            return parts
        case .sell:
            let words = line.text.split(separator: " ")
            if words.count > 1, let last = words.last,
               let price = Double(last.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: ",", with: ".")) {
                return ["To sell", "asking \(euros(Money.cents(fromEuros: price)))"]
            }
            return ["To sell", "price later"]
        case .partner: return ["New person", "On my list"]
        default: return [kind.title]
        }
    }

    private func matchesSection(_ found: [AnyRecord]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader("Already here", count: found.count)
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

    private var addedSection: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader("Just added", count: added.count)
            ForEach(added) { rec in
                HStack(spacing: Metrics.s) {
                    NavigationLink { RecordDestination(record: rec) } label: {
                        RecordRow(record: rec, showType: false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button("Undo") { undo(rec) }
                        .buttonStyle(.brutalCompact)
                }
                .padding(Metrics.m)
                .brutalBox(radius: Metrics.radiusSmall)
            }
        }
    }

    private var hints: some View {
        VStack(alignment: .leading, spacing: 6) {
            Cap("Type it like you'd say it")
            hint("Call Anna friday #support", "a task with a date and area")
            hint("@Anna Jansen", "a new person on your list")
            hint("pray: the visa interview", "a prayer point")
            hint("thanks: coffee with Jan", "a thank-you")
            hint("sell: Bike 150", "something to sell, with a price")
            hint("pack: charger", "something to pack")
        }
        .padding(.top, 4)
    }

    private func hint(_ example: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(example).font(Typeface.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(meaning).font(Typeface.body(13)).foregroundStyle(Palette.muted)
        }
    }

    // MARK: Data

    private var matches: [AnyRecord] {
        let q = line.text
        guard q.count >= 2 else { return [] }
        let justAdded = Set(added.map(\.id))
        return Array(AnyRecord.everything(ctx)
            .filter { !justAdded.contains($0.id) && $0.searchText.localizedCaseInsensitiveContains(q) }
            .prefix(5))
    }

    private func save() {
        guard let rec = Capture.save(line.text, as: kind, linkTo: context?.link, ctx) else { return }
        withAnimation(.easeOut(duration: 0.18)) { added.insert(rec, at: 0) }
        text = ""
        focused = true
    }

    private func undo(_ rec: AnyRecord) {
        withAnimation(.easeOut(duration: 0.18)) { added.removeAll { $0.id == rec.id } }
        rec.delete(ctx)
    }
}
