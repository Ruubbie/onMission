import SwiftUI
import SwiftData

struct TasksView: View {
    enum Grouping: String, CaseIterable, Identifiable {
        case week = "By week", area = "By area", done = "Done"
        var id: String { rawValue }
    }

    /// A titled group of tasks.
    struct TaskSection: Identifiable {
        let title: String
        let tasks: [Todo]
        var id: String { title }
    }

    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Todo.order)]) private var tasks: [Todo]
    @State private var grouping: Grouping = .week
    @State private var areaFilter: Area?
    @State private var search = ""
    @State private var quick = ""
    @State private var opened: Todo?

    /// Checklist items without a date live in their checklist, not here.
    private var visible: [Todo] {
        tasks.filter { t in
            (t.checklistID.isEmpty || t.dueDate != nil)
                && (grouping == .done ? t.isDone : !t.isDone)
                && (areaFilter == nil || t.areaValue == areaFilter)
                && (search.isEmpty || t.title.localizedCaseInsensitiveContains(search)
                    || t.notes.localizedCaseInsensitiveContains(search))
        }
    }

    private var groups: [TaskSection] {
        let list = visible
        switch grouping {
        case .area:
            return Area.allCases.compactMap { a in
                let ts = list.filter { $0.areaValue == a }.sorted(by: Insights.byDue)
                return ts.isEmpty ? nil : TaskSection(title: a.title, tasks: ts)
            }
        case .done:
            let sorted = list.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            return sorted.isEmpty ? [] : [TaskSection(title: "Done", tasks: sorted)]
        case .week:
            return Self.byWeek(list)
        }
    }

    static func byWeek(_ list: [Todo]) -> [TaskSection] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var weeks: [Date: [Todo]] = [:]
        var overdue: [Todo] = []
        var someday: [Todo] = []
        for t in list {
            guard let due = t.dueDate else { someday.append(t); continue }
            if due < today { overdue.append(t); continue }
            let week = cal.dateInterval(of: .weekOfYear, for: due)?.start ?? due
            weeks[week, default: []].append(t)
        }
        var out: [TaskSection] = []
        if !overdue.isEmpty { out.append(TaskSection(title: "Overdue", tasks: overdue.sorted(by: Insights.byDue))) }
        for week in weeks.keys.sorted() {
            let title = cal.isDate(week, equalTo: today, toGranularity: .weekOfYear)
                ? "This week" : "Week of \(week.formatted(.dateTime.day().month(.abbreviated)))"
            out.append(TaskSection(title: title, tasks: (weeks[week] ?? []).sorted(by: Insights.byDue)))
        }
        if !someday.isEmpty { out.append(TaskSection(title: "No date", tasks: someday)) }
        return out
    }

    var body: some View {
        List {
            controls
            ForEach(groups) { group in
                SectionHeader(group.title, count: group.tasks.count, accent: group.title == "Overdue" ? .pink : .yellow)
                    .brutalRow(top: 14, bottom: 2)
                ForEach(group.tasks) { t in
                    TaskCardRow(task: t, showArea: grouping != .area)
                        .brutalRow()
                        .swipeActions(edge: .leading) {
                            Button(t.isDone ? "Undo" : "Done") { toggle(t) }.tint(Palette.ok)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { Store.delete(t, in: ctx) }
                            Button("Tomorrow") { move(t, days: 1) }.tint(Accent.purple.color)
                        }
                        .contextMenu { menu(for: t) }
                }
            }
            if groups.isEmpty {
                BrutalEmptyState(symbol: "checkmark", title: grouping == .done ? "Nothing done yet" : "All clear",
                                 message: grouping == .done ? "Ticked tasks show up here." : "No open tasks match.")
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .brutalSearch(text: $search)
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { areaMenu }
        }
        .addButton(newTask)
        .navigationDestination(item: $opened) { TaskDetail(task: $0) }
    }

    @ViewBuilder
    private var controls: some View {
        QuickAddField(prompt: "New task (try \"Book GP friday #health\")", text: $quick, onSubmit: add)
            .brutalRow(top: 8, bottom: 6)
        BrutalSegmented(options: Grouping.allCases.map { ($0, $0.rawValue) }, selection: $grouping)
            .padding(.trailing, Metrics.shadowSmall)
        .brutalRow(top: 6, bottom: 4)
        if let a = areaFilter {
            HStack {
                FilterChip(text: a.title, accent: a.accent, symbol: "xmark", selected: true) { areaFilter = nil }
                Spacer()
            }
            .brutalRow(top: 2, bottom: 2)
        }
    }

    private var areaMenu: some View {
        Menu {
            Picker("Area", selection: $areaFilter) {
                Text("All areas").tag(Area?.none)
                ForEach(Area.allCases) { a in
                    Label(a.title, systemImage: a.symbol).tag(Area?.some(a))
                }
            }
        } label: {
            IconTile(symbol: "line.3.horizontal.decrease", accent: areaFilter == nil ? nil : .yellow, size: 36)
        }
    }

    @ViewBuilder
    private func menu(for t: Todo) -> some View {
        Button(t.isDone ? "Mark not done" : "Mark done") { toggle(t) }
        Menu("Move to") {
            Button("Today") { t.dueDate = Calendar.current.startOfDay(for: .now) }
            Button("Tomorrow") { move(t, days: 1) }
            Button("Next week") { move(t, days: 7) }
            Button("No date") { t.dueDate = nil }
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
        withAnimation {
            t.setDone(!t.isDone)
            Automations.taskDone(t, ctx)
        }
    }

    private func move(_ t: Todo, days: Int) {
        let base = max(t.dueDate ?? .now, Calendar.current.startOfDay(for: .now))
        t.dueDate = Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: base))
    }

    private func add() {
        let parsed = QuickAdd.parse(quick)
        guard !parsed.title.isEmpty else { return }
        let t = Automations.addTask(parsed.title, due: parsed.due, area: parsed.area ?? areaFilter ?? .other, ctx)
        if let p = parsed.priority { t.priorityValue = p }
        quick = ""
    }

    private func newTask() {
        let t = Automations.addTask("", due: nil, area: areaFilter ?? .other, ctx)
        opened = t
    }
}

// MARK: - Rows

/// The tick box for a task.
struct TaskCheckbox: View {
    @Environment(\.modelContext) private var ctx
    let task: Todo

    var body: some View {
        Button {
            withAnimation {
                task.setDone(!task.isDone)
                Automations.taskDone(task, ctx)
            }
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(task.isDone ? Palette.ink : Color.clear)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 5).fill(task.isDone ? Accent.green.color : Palette.paper))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: Metrics.border))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
    }
}

/// Checkbox, title and chips. With `opensDetail` the text opens the task (for use outside Lists).
struct TaskRow: View {
    let task: Todo
    var showArea: Bool = true
    var opensDetail: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.m) {
            TaskCheckbox(task: task)
            if opensDetail {
                NavigationLink { TaskDetail(task: task) } label: { text }
                    .buttonStyle(.plain)
            } else {
                text
            }
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.displayTitle)
                .font(Typeface.body(16, weight: .semibold))
                .foregroundStyle(task.isDone ? Palette.muted : Palette.ink)
                .strikethrough(task.isDone)
                .multilineTextAlignment(.leading)
            TaskMeta(task: task, showArea: showArea)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct TaskMeta: View {
    let task: Todo
    let showArea: Bool

    var body: some View {
        HStack(spacing: 6) {
            if showArea { Chip(text: task.areaValue.title, accent: task.areaValue.accent, symbol: task.areaValue.symbol) }
            if task.statusValue == .doing || task.statusValue == .waiting {
                Chip(text: task.statusValue.title, accent: .sand)
            }
            if task.priorityValue == .high { Chip(text: "High", accent: .pink, symbol: "exclamationmark") }
            if let due = task.dueDate {
                Text(shortDate(due))
                    .font(Typeface.body(13, weight: .semibold))
                    .foregroundStyle(task.isOverdue ? Palette.danger : Palette.muted)
            }
        }
    }
}

/// A task as a card in the Tasks list.
struct TaskCardRow: View {
    let task: Todo
    var showArea: Bool = true

    var body: some View {
        CardLink {
            TaskDetail(task: task)
        } label: {
            TaskRow(task: task, showArea: showArea)
                .padding(Metrics.m)
                .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
        }
    }
}

// MARK: - Detail

struct TaskDetail: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var task: Todo
    @Query private var checklists: [Checklist]

    var body: some View {
        Form {
            FormHeroRow(fill: task.areaValue.accent == .purple ? Palette.softPink : Palette.softYellow) {
                TextField("Task", text: $task.title, axis: .vertical)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: Metrics.s) {
                    TaskCheckbox(task: task)
                    Text(task.isDone ? "Done" : "Not done yet")
                        .font(Typeface.body(15, weight: .semibold))
                    Spacer()
                    Chip(text: task.areaValue.title, accent: task.areaValue.accent, symbol: task.areaValue.symbol)
                }
            }

            Section {
                BrutalSelect("Status", selection: statusBinding) {
                    ForEach(TaskStatus.allCases) { Text($0.title).tag($0) }
                }
                if task.statusValue == .waiting {
                    TextField("Waiting on (person, office…)", text: $task.waitingOn)
                }
                BrutalSelect("Area", selection: Binding(get: { task.areaValue }, set: { task.areaValue = $0 })) {
                    ForEach(Area.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                BrutalSelect("Priority", selection: Binding(get: { task.priorityValue }, set: { task.priorityValue = $0 })) {
                    ForEach(Priority.allCases) { Text($0.title).tag($0) }
                }
                OptionalDatePicker(title: "Due date", date: $task.dueDate)
            } header: { FormHeader("Task") }

            Section {
                Toggle("Remind me", isOn: Binding(
                    get: { task.remindAt != nil },
                    set: { task.remindAt = $0 ? (task.remindAt ?? defaultReminder) : nil }
                ))
                if let remind = task.remindAt {
                    BrutalDateRow(title: "At", date: Binding(get: { remind }, set: { task.remindAt = $0 }), components: [.date, .hourAndMinute])
                }
            } header: { FormHeader("Reminder") }

            if let list = checklists.first(where: { $0.id == task.checklistID }) {
                Section {
                    NavigationLink { ChecklistDetail(list: list) } label: {
                        Label(list.displayTitle, systemImage: "checklist")
                    }
                } header: { FormHeader("In checklist") }
            }

            Section {
                TextField("Anything you want to remember", text: $task.notes, axis: .vertical)
                    .lineLimit(3...12)
                TextField("Link (website, form…)", text: $task.sourceURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let url = URL(string: task.sourceURL), !task.sourceURL.isEmpty, url.scheme != nil {
                    Link(destination: url) { Label("Open link", systemImage: "safari") }
                }
            } header: { FormHeader("Notes") }

            LinksSection(record: .task(task))

            Section { DeleteRecordButton(item: task) }
        }
        .brutalForm()
        .navigationTitle(task.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await Reminders.refresh(ctx) } }
    }

    private var statusBinding: Binding<TaskStatus> {
        Binding(get: { task.statusValue }, set: { new in
            task.statusValue = new
            task.completedAt = task.isDone ? (task.completedAt ?? Date.now) : nil
            Automations.taskDone(task, ctx)
        })
    }

    private var defaultReminder: Date {
        let base = task.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
    }
}
