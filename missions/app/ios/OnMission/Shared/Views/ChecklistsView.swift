import SwiftUI
import SwiftData

/// The four stops on the Checklists page. Ongoing lists sit with Arrival.
enum ChecklistStop: String, CaseIterable, Hashable {
    case now, before, leaving, arrival

    var title: String {
        switch self {
        case .now: "Now"
        case .before: "Before"
        case .leaving: "Leaving"
        case .arrival: "Arrival"
        }
    }

    func contains(_ phase: ChecklistPhase) -> Bool {
        switch self {
        case .now: phase == .now
        case .before: phase == .beforeDeparture
        case .leaving: phase == .departureWeek
        case .arrival: phase == .arrival || phase == .ongoing
        }
    }
}

// MARK: - Checklists (handoff §7): things left, lists with rings that fill

struct ChecklistsPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Checklist.order) private var lists: [Checklist]
    @Query private var tasks: [Todo]
    @State private var stop: ChecklistStop = .now
    @State private var openID: String?
    @State private var slide = 0
    @State private var direction: CGFloat = 1
    @State private var showArchived = false
    @State private var chosen = false

    private var items: [Todo] { tasks.filter { !$0.checklistID.isEmpty } }

    private func left(_ stop: ChecklistStop?) -> Int {
        let ids = Set(lists.filter { list in !list.archived && (stop?.contains(list.phaseValue) ?? true) }.map(\.id))
        return items.filter { ids.contains($0.checklistID) && !$0.isDone }.count
    }

    private func shown(_ stop: ChecklistStop) -> [Checklist] {
        lists.filter { (showArchived || !$0.archived) && stop.contains($0.phaseValue) }
    }

    var body: some View {
        let active = lists.filter { !$0.archived }
        let all = left(nil)
        let archived = lists.count - active.count
        let segments = ChecklistStop.allCases.map { Segments<ChecklistStop>.Item(value: $0, title: $0.title, count: left($0)) }
        let visible = shown(stop)
        let byList = Dictionary(grouping: items, by: \.checklistID)
        // Three digits at 184 run into the aside and the stones.
        let size: CGFloat = all >= 100 ? 150 : 184
        Screen(posterHeight: 306, sheetTop: 10) {
            Hand("Before you fly").rise(0).at(24, 106)
            Text("\(all)")
                .type(.disp(size))
                .contentTransition(.numericText(value: Double(all)))
                .animation(.easeOut(duration: 0.48), value: all)
                .lineLimit(1)
                .offset(y: FontMetrics.shift(.archivo, size: size, lineHeight: 0.78) + (184 - size) * 0.5)
                .rise(1)
                .at(18, 136)
            CapLine("Things left\non \(active.count) list\(active.count == 1 ? "" : "s")").rise(2).at(24, 292)
            LineArt(drawing: Art.stones).at(200, 120)
        } sheet: {
            Segments(items: segments, selection: $stop, tight: true)
            SheetScroll {
                Group {
                    ForEach(visible) { list in
                        ChecklistBox(list: list,
                                     items: (byList[list.id] ?? []).sorted { $0.order < $1.order },
                                     open: openID == list.id) { toggle(list) }
                    }
                    if visible.isEmpty {
                        EmptyRow(title: "Nothing for this stop", message: "Start a list below, or pick another stop.")
                    }
                }
                .slideIn(slide, direction: direction)
                FormBlock("") {
                    ActionRow(title: "New checklist", icon: .plus) { newList() }
                    if archived > 0 {
                        ActionRow(title: showArchived ? "Hide archived" : "Show archived · \(archived)", icon: .archive) {
                            withAnimation(Motion.fold.rm) { showArchived.toggle() }
                        }
                    }
                }
            }
        }
        .onAppear {
            if !chosen {
                chosen = true
                stop = ChecklistStop.allCases.first { left($0) > 0 } ?? .now
            }
            // The first list opens itself.
            Motion.after(0.62) { openFirst() }
        }
        .onChange(of: stop) { old, new in
            direction = Segments<ChecklistStop>.direction(from: old, to: new, in: segments)
            slide += 1
            openID = nil
            Motion.after(0.25) { openFirst() }
        }
        .captureContext(.task)
    }

    private func openFirst() {
        guard openID == nil, let first = shown(stop).first else { return }
        withAnimation(.curve(0.3, 0.9, 0.3, 1, 0.42).rm) { openID = first.id }
    }

    private func toggle(_ list: Checklist) {
        withAnimation(.curve(0.3, 0.9, 0.3, 1, 0.42).rm) {
            openID = openID == list.id ? nil : list.id
        }
    }

    private func newList() {
        let list = Checklist()
        list.title = "New checklist"
        list.order = (lists.map(\.order).max() ?? 0) + 1
        list.phaseValue = switch stop {
        case .now: .now
        case .before: .beforeDeparture
        case .leaving: .departureWeek
        case .arrival: .arrival
        }
        ctx.insert(list)
        router.push(.checklist(list))
    }
}

/// A list as a row: its ring and "3 of 5 done"; tap to show its items.
private struct ChecklistBox: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    let list: Checklist
    let items: [Todo]
    let open: Bool
    let toggle: () -> Void
    @State private var newText = ""
    @State private var pop = 0
    @State private var chev = 0

    var body: some View {
        let done = items.filter(\.isDone).count
        let n = items.count
        let full = n > 0 && done == n
        VStack(alignment: .leading, spacing: 0) {
            Button {
                chev += 1
                toggle()
            } label: {
                HStack(spacing: 14) {
                    ProgressRing(fraction: n == 0 ? 0 : Double(done) / Double(n))
                        .pop(pop, to: 1.3)
                    RowText(title: list.displayTitle,
                            subtitle: n == 0 ? "No items yet" : (full ? "All done" : "\(done) of \(n) done"))
                    AnimatedIcon(.chev, size: 20, trigger: chev)
                        .foregroundStyle(Palette.tomato)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .opacity(list.archived ? 0.55 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hides the items" : "Shows the items")
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        ChecklistItemRow(item: item)
                    }
                    HStack(spacing: 12) {
                        AnimatedIcon(.plus, size: 18).foregroundStyle(Palette.tomato).frame(width: 22)
                        TextField("", text: $newText, prompt: Text("Add an item").foregroundStyle(Palette.inkFaint))
                            .type(.bodyBold)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                    .padding(.vertical, 10)
                    Button { router.push(.checklist(list)) } label: {
                        HStack(spacing: 6) {
                            Text("Edit list").type(.buttonSmall)
                            AnimatedIcon(.arrow, size: 15)
                        }
                        .foregroundStyle(Palette.tomatoInk)
                        .frame(minHeight: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.press)
                    .padding(.bottom, 6)
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        .clipped()
        .sensoryFeedback(.success, trigger: pop)
        .onChange(of: full) { was, now in
            guard now && !was else { return }
            Motion.after(0.38) { pop += 1 }
            router.showToast("\(list.displayTitle) · all done")
        }
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let item = Todo()
        item.title = text
        item.checklistID = list.id
        item.areaValue = list.areaValue
        item.order = (items.map(\.order).max() ?? 0) + 1
        withAnimation(Motion.arrive.rm) { ctx.insert(item) }
        newText = ""
    }
}

/// One checklist item: a ring to tick and its words; tap the words to open it as a task.
struct ChecklistItemRow: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    let item: Todo

    var body: some View {
        HStack(spacing: 12) {
            RingButton(ticked: item.isDone, size: 22) { tick() }
            Text(item.displayTitle)
                .type(.bodyBold)
                .strikethrough(item.isDone, color: Palette.ink)
                .opacity(item.isDone ? 0.5 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.record(.task(item))) }
            if let due = item.dueDate, !item.isDone {
                WhenText(text: whenText(due), late: item.isOverdue)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.record(.task(item))) }
        .accessibilityAction(named: item.isDone ? "Untick" : "Tick") { tick() }
    }

    private func tick() {
        withAnimation(.easeOut(duration: 0.22)) {
            item.setDone(!item.isDone)
            Automations.taskDone(item, ctx)
        }
    }
}

// MARK: - One checklist

struct ChecklistDetail: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var list: Checklist
    @Query private var items: [Todo]
    @State private var newText = ""

    init(list: Checklist) {
        self.list = list
        let id = list.id
        _items = Query(filter: #Predicate<Todo> { $0.checklistID == id }, sort: \Todo.order)
    }

    var body: some View {
        let done = items.filter(\.isDone).count
        DetailPage(aside: list.phaseValue.title, title: list.displayTitle,
                   cap: items.isEmpty ? "No items yet" : "\(done) of \(items.count) done") {
            HStack(spacing: 14) {
                ProgressRing(fraction: items.isEmpty ? 0 : Double(done) / Double(items.count))
                SectionHeader("Items", count: items.count)
            }
            .padding(.bottom, 4)
            ForEach(items) { item in
                ChecklistItemRow(item: item)
                    .contextMenu {
                        Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                    }
            }
            FieldRow {
                AnimatedIcon(.plus, size: 18).foregroundStyle(Palette.tomato).frame(width: 22)
                TextField("", text: $newText, prompt: Text("Add an item").foregroundStyle(Palette.inkFaint))
                    .type(.bodyBold)
                    .submitLabel(.done)
                    .onSubmit(add)
            }
            FormBlock("Details") {
                TextRow("Title", text: $list.title)
                TextRow("Description", text: $list.desc, vertical: true, lines: 1...6)
                SelectRow("When", selection: Binding(get: { list.phaseValue }, set: { list.phaseValue = $0 })) {
                    ForEach(ChecklistPhase.allCases) { Text($0.title).tag($0) }
                }
                SelectRow("Area", selection: Binding(get: { list.areaValue }, set: { list.areaValue = $0 })) {
                    ForEach(Area.allCases) { Text($0.title).tag($0) }
                }
                ToggleRow("Archived", isOn: $list.archived)
            }
            if done > 0 {
                ActionRow(title: "Untick everything", icon: .undo) {
                    withAnimation(Motion.fold.rm) {
                        for item in items where item.isDone { item.setDone(false) }
                    }
                }
            }
            LinksBlock(record: .checklist(list))
            DeleteButton(item: list, extra: { [items, ctx] in
                for item in items { Store.delete(item, in: ctx) }
            })
        }
        .captureContext(.task, linkTo: .checklist(list))
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let item = Todo()
        item.title = text
        item.checklistID = list.id
        item.areaValue = list.areaValue
        item.order = (items.map(\.order).max() ?? 0) + 1
        withAnimation(Motion.arrive.rm) { ctx.insert(item) }
        newText = ""
    }
}
