import SwiftUI
import SwiftData

/// Tasks (handoff §5): "TASKS" on tomato, the sheet starts high because the list is the point.
/// Today · This week · Later, with the existing swipe actions.
struct TasksView: View {
    enum Bucket: String, CaseIterable {
        case today, week, later
        var title: String {
            switch self {
            case .today: "Today"
            case .week: "This week"
            case .later: "Later"
            }
        }
    }

    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: [SortDescriptor(\Todo.order)]) private var tasks: [Todo]
    @State private var bucket: Bucket = .today
    @State private var slide = 0
    @State private var direction: CGFloat = 1

    /// Checklist items without a date live in their checklist, not here.
    private var open: [Todo] {
        tasks.filter { !$0.isDone && ($0.checklistID.isEmpty || $0.dueDate != nil) }
    }

    /// Today = overdue + today; This week = tomorrow + the next 7 days; Later = later + no date.
    static func bucket(of t: Todo) -> Bucket {
        guard let due = t.dueDate else { return .later }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if due < (cal.date(byAdding: .day, value: 1, to: today) ?? today) { return .today }
        if due < (cal.date(byAdding: .day, value: 8, to: today) ?? today) { return .week }
        return .later
    }

    var body: some View {
        let all = open
        let groups = Dictionary(grouping: all, by: Self.bucket)
        let rows = (groups[bucket] ?? []).sorted(by: Insights.byDue)
        let items = Bucket.allCases.map { Segments<Bucket>.Item(value: $0, title: $0.title, count: groups[$0]?.count ?? 0) }
        Screen(posterHeight: 186, sheetTop: 10) {
            Lines("Tasks", .disp(92)).rise(0).at(22, 114)
            Hand(all.isEmpty ? "All clear" : "\(all.count) left, you got this", size: 30, tilt: -5).rise(1).at(28, 212)
            LineArt(drawing: Art.clipboard).at(268, 104)
        } sheet: {
            Segments(items: items, selection: $bucket)
            List {
                ForEach(rows) { t in
                    TaskRow(task: t, subtitle: t.areaValue.title, when: whenText(t.dueDate), late: t.isOverdue,
                            rule: t.id != rows.last?.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.sheetSide, bottom: 0, trailing: Metrics.sheetSide))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading) {
                            Button("Done") { toggle(t) }.tint(Palette.tomato)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { Store.delete(t, in: ctx) }
                            Button("Next week") { reschedule(t, days: 7) }.tint(Palette.plum)
                            Button("Tomorrow") { reschedule(t, days: 1) }.tint(Palette.marigold)
                        }
                        .contextMenu { menu(for: t) }
                }
                if rows.isEmpty {
                    EmptyRow(title: bucket == .today ? "Nothing due today" : "Nothing here",
                             message: "Add one with the + at the top.")
                        .listRowInsets(EdgeInsets(top: 0, leading: Metrics.sheetSide, bottom: 0, trailing: Metrics.sheetSide))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Color.clear.frame(height: 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
            .padding(.horizontal, -Metrics.sheetSide)
            .padding(.top, 4)
            .slideIn(slide, direction: direction)
        }
        .onChange(of: bucket) { old, new in
            direction = Segments<Bucket>.direction(from: old, to: new, in: items)
            slide += 1
        }
        .captureContext(.task)
    }

    @ViewBuilder
    private func menu(for t: Todo) -> some View {
        Button(t.isDone ? "Mark not done" : "Mark done") { toggle(t) }
        Menu("Move to") {
            Button("Today") { reschedule(t, days: 0) }
            Button("Tomorrow") { reschedule(t, days: 1) }
            Button("Next week") { reschedule(t, days: 7) }
            Button("No date") { withAnimation { t.dueDate = nil } }
        }
        Menu("Status") {
            ForEach(TaskStatus.allCases) { s in
                Button(s.title) {
                    t.statusValue = s
                    t.completedAt = t.isDone ? Date.now : nil
                    Automations.taskDone(t, ctx)
                }
            }
        }
        Button("Delete", role: .destructive) { Store.delete(t, in: ctx) }
    }

    private func toggle(_ t: Todo) {
        withAnimation(Motion.fold.rm) {
            t.setDone(!t.isDone)
            Automations.taskDone(t, ctx)
        }
    }

    /// Due a number of days from today (overdue tasks move forward from today, not from their old date).
    private func reschedule(_ t: Todo, days: Int) {
        withAnimation(Motion.fold.rm) {
            t.dueDate = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: .now))
        }
        router.showToast(days == 0 ? "Moved to today" : (days == 1 ? "Moved to tomorrow" : "Moved to next week"))
    }
}

// MARK: - A task as a row

/// Ring, title, subtitle and when. Tap the ring to tick it (the check draws, the title strikes through,
/// the row folds away); tap the row to open the task.
struct TaskRow: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    let task: Todo
    var subtitle: String = ""
    var when: String? = nil
    var late = false
    var rule = true
    @State private var ticked = false

    var body: some View {
        Row(rule: rule) {
            RingButton(ticked: ticked || task.isDone) { tick() }
            RowText(title: task.displayTitle, subtitle: subtitle, late: late && when == nil, struck: ticked || task.isDone)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.task(task)) }
            if let when {
                WhenText(text: when, late: late)
                    .contentShape(Rectangle())
                    .onTapGesture { router.push(.task(task)) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.task(task)) }
        .accessibilityAction(named: "Mark done") { tick() }
    }

    private func tick() {
        guard !ticked, !task.isDone else { return }
        ticked = true
        let t = task
        let context = ctx
        Motion.after(0.56) {
            withAnimation(Motion.fold.rm) {
                t.setDone(true)
                Automations.taskDone(t, context)
            }
        }
    }
}

// MARK: - The Task page

/// Its area by hand, its title big, when it's due; pick when, jump to what it's linked to, mark it done.
struct TaskPage: View {
    enum When: String, CaseIterable {
        case today, tomorrow, week, none
        var title: String {
            switch self {
            case .today: "Today"
            case .tomorrow: "Tomorrow"
            case .week: "Next week"
            case .none: "No date"
            }
        }
        var days: Int? {
            switch self {
            case .today: 0
            case .tomorrow: 1
            case .week: 7
            case .none: nil
            }
        }
    }

    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Bindable var task: Todo
    @Query private var checklists: [Checklist]
    @State private var when: When = .today
    @State private var donePlay = 0
    @State private var done = false
    @State private var showDetails = false

    init(task: Todo) {
        self.task = task
        _when = State(initialValue: Self.when(of: task.dueDate))
    }

    var body: some View {
        let size: CGFloat = task.displayTitle.count > 22 ? 58 : 68
        Screen(posterHeight: 306) {
            Hand(task.areaValue.title).rise(0).at(24, 106)
            VStack(alignment: .leading, spacing: 0) {
                Lines(wrapLines(task.displayTitle, .disp(size), width: 346, maxLines: 3), .disp(size), lineHeight: 0.9, minScale: 0.6)
                CapLine(dueLine)
                    .id(dueLine)
                    .transition(.asymmetric(insertion: .offset(y: 14).combined(with: .opacity), removal: .offset(y: -14).combined(with: .opacity)))
                    .padding(.top, 16)
                    .padding(.leading, 2)
            }
            .frame(width: 346, alignment: .leading)
            .rise(1)
            .at(22, 146)
        } sheet: {
            SheetScroll { sheet }
        }
        .captureContext(.task, linkTo: .task(task))
        .onDisappear { Task { await Reminders.refresh(ctx) } }
    }

    private var dueLine: String {
        if task.isDone { return "Done" }
        guard let due = task.dueDate else { return "No date" }
        if task.isOverdue { return "Was due \(shortDate(due, midSentence: true))" }
        return "Due \(shortDate(due, midSentence: true))"
    }

    static func when(of date: Date?) -> When {
        guard let date else { return .none }
        let cal = Calendar.current
        if date < (cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now) { return .today }
        if cal.isDateInTomorrow(date) { return .tomorrow }
        return .week
    }

    @ViewBuilder
    private var sheet: some View {
        SectionHeader("When")
        Pills(items: When.allCases.map { Pills<When>.Item(value: $0, title: $0.title) }, selection: $when, tight: true)
            .padding(.top, 10)
            .onChange(of: when) { _, new in move(to: new) }

        let linked = Links.linked(to: .task(task), ctx)
        if !linked.isEmpty {
            SectionHeader("Linked to").padding(.top, 6)
            ForEach(Array(linked.enumerated()), id: \.element.id) { index, rec in
                LinkedRow(record: rec, rule: index < linked.count - 1)
            }
        }

        Button {
            markDone()
        } label: {
            ButtonLabel(title: done || task.isDone ? "Done" : "Mark done", icon: .check, trigger: donePlay)
        }
        .buttonStyle(.wide)
        .pop(donePlay)
        .padding(.top, 16)
        .disabled(done)
        .sensoryFeedback(.success, trigger: donePlay)

        MoreLink(title: showDetails ? "Fewer details" : "More details") {
            withAnimation(.easeOut(duration: 0.25)) { showDetails.toggle() }
        }
        if showDetails { details.transition(.opacity) }
    }

    private func move(to w: When) {
        let target = w.days.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) }
        if Self.when(of: task.dueDate) == w { return }
        withAnimation(.curve(0.2, 0.85, 0.25, 1, 0.34).rm) { task.dueDate = target }
        router.showToast(w == .none ? "Moved to no date" : "Moved to \(w.title.lowercased())")
    }

    private func markDone() {
        guard !done else { return }
        done = true
        donePlay += 1
        Motion.after(0.65) {
            router.back()
            Motion.after(0.56, always: true) {
                withAnimation(Motion.fold.rm) {
                    task.setDone(true)
                    Automations.taskDone(task, ctx)
                }
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        FormBlock("Task") {
            TitleField(placeholder: "Task", text: $task.title)
            SelectRow("Status", selection: Binding(get: { task.statusValue }, set: { new in
                task.statusValue = new
                task.completedAt = task.isDone ? (task.completedAt ?? .now) : nil
                Automations.taskDone(task, ctx)
            })) {
                ForEach(TaskStatus.allCases) { Text($0.title).tag($0) }
            }
            if task.statusValue == .waiting {
                TextRow("Waiting on (person, office…)", text: $task.waitingOn)
            }
            SelectRow("Area", selection: Binding(get: { task.areaValue }, set: { task.areaValue = $0 })) {
                ForEach(Area.allCases) { Text($0.title).tag($0) }
            }
            SelectRow("Priority", selection: Binding(get: { task.priorityValue }, set: { task.priorityValue = $0 })) {
                ForEach(Priority.allCases) { Text($0.title).tag($0) }
            }
            OptionalDateRow(title: "Due date", date: $task.dueDate)
        }
        FormBlock("Reminder") {
            ToggleRow("Remind me", isOn: Binding(
                get: { task.remindAt != nil },
                set: { task.remindAt = $0 ? (task.remindAt ?? defaultReminder) : nil }
            ))
            if let remind = task.remindAt {
                DateRow(title: "At", date: Binding(get: { remind }, set: { task.remindAt = $0 }), components: [.date, .hourAndMinute])
            }
        }
        if let list = checklists.first(where: { $0.id == task.checklistID }) {
            FormBlock("In checklist") {
                ActionRow(title: list.displayTitle, icon: .list) { router.push(.checklist(list)) }
            }
        }
        FormBlock("Notes") {
            TextRow("Anything you want to remember", text: $task.notes, vertical: true, lines: 3...12)
            TextRow("Link (website, form…)", text: $task.sourceURL, keyboard: .URL, plain: true)
            if let url = URL(string: task.sourceURL), !task.sourceURL.isEmpty, url.scheme != nil {
                Link(destination: url) {
                    FieldRow { AnimatedIcon(.link, size: 20).foregroundStyle(Palette.tomato); Text("Open link").type(.bodyBold) }
                }
            }
        }
        LinksBlock(record: .task(task))
        DeleteButton(item: task)
    }

    private var defaultReminder: Date {
        let base = task.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
    }
}

/// A linked record as a row: an avatar for a person, a document box for anything else. Opens its page.
struct LinkedRow: View {
    @Environment(Router.self) private var router
    let record: AnyRecord
    var rule = true
    @State private var play = 0

    var body: some View {
        Button {
            play += 1
            router.open(record)
        } label: {
            Row(rule: rule) {
                switch record {
                case .partner(let p): Avatar(name: p.displayTitle)
                case .contact(let c): Avatar(name: c.displayTitle)
                default: DocBox(icon: record.icon, trigger: play)
                }
                RowText(title: record.title, subtitle: record.typeLabel)
                AnimatedIcon(.chev, size: 20, trigger: play).foregroundStyle(Palette.tomato)
            }
        }
        .buttonStyle(.plain)
    }
}

extension Router {
    /// Opens the right page for any record.
    func open(_ record: AnyRecord) {
        switch record {
        case .partner(let p): push(.partner(p))
        case .task(let t) where t.checklistID.isEmpty: push(.task(t))
        case .checklist(let c): push(.checklist(c))
        default: push(.record(record))
        }
    }
}
