import SwiftUI
import SwiftData

/// Checklists, grouped by when they matter. Their items are tasks with a checklistID.
struct ChecklistsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Checklist.order) private var lists: [Checklist]
    @Query private var tasks: [Todo]
    @State private var opened: Checklist?
    @State private var showArchived = false

    private var shown: [Checklist] { lists.filter { showArchived || !$0.archived } }

    var body: some View {
        List {
            ForEach(ChecklistPhase.allCases) { phase in
                let inPhase = shown.filter { $0.phaseValue == phase }
                if !inPhase.isEmpty {
                    SectionHeader(phase.title, count: inPhase.count, accent: .lime)
                        .brutalRow(top: 14, bottom: 2)
                    ForEach(inPhase) { list in
                        CardLink {
                            ChecklistDetail(list: list)
                        } label: {
                            ChecklistCard(list: list, items: tasks.filter { $0.checklistID == list.id })
                        }
                        .brutalRow()
                        .swipeActions {
                            Button("Delete", role: .destructive) { delete(list) }
                            Button(list.archived ? "Unarchive" : "Archive") { list.archived.toggle() }
                                .tint(Palette.muted)
                        }
                    }
                }
            }
            if shown.isEmpty {
                BrutalEmptyState(symbol: "checklist", title: "No checklists yet",
                                 message: "Packing, deregistration, health before you leave… tap + to start one.", accent: .lime)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .navigationTitle("Checklists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $showArchived) { Image(systemName: "archivebox") }
                    .toggleStyle(.button)
                    .tint(Palette.ink)
            }
        }
        .addButton(newList)
        .navigationDestination(item: $opened) { ChecklistDetail(list: $0) }
    }

    private func newList() {
        let list = Checklist()
        list.title = "New checklist"
        list.order = (lists.map(\.order).max() ?? 0) + 1
        ctx.insert(list)
        opened = list
    }

    private func delete(_ list: Checklist) {
        for item in tasks where item.checklistID == list.id { Store.delete(item, in: ctx) }
        Store.delete(list, in: ctx)
    }
}

private struct ChecklistCard: View {
    let list: Checklist
    let items: [Todo]

    var body: some View {
        let done = items.filter(\.isDone).count
        VStack(alignment: .leading, spacing: Metrics.s) {
            HStack(spacing: Metrics.m) {
                AccentSquareIcon(symbol: list.areaValue.symbol, accent: list.areaValue.accent, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.displayTitle)
                        .font(Typeface.heading(17))
                        .foregroundStyle(Palette.ink)
                    if !list.desc.isEmpty {
                        Text(list.desc).font(Typeface.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text("\(done)/\(items.count)")
                    .font(Typeface.heading(17))
                    .foregroundStyle(Palette.ink)
            }
            BrutalProgress(value: items.isEmpty ? 0 : Double(done) / Double(items.count), accent: .lime, height: 12)
        }
        .padding(Metrics.m)
        .brutalBox(fill: list.archived ? Palette.altRow : Palette.paper, radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

struct ChecklistDetail: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable var list: Checklist
    @Query private var items: [Todo]
    @State private var newText = ""
    @State private var hideDone = false
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var showLinks = false

    init(list: Checklist) {
        self.list = list
        let id = list.id
        _items = Query(filter: #Predicate<Todo> { $0.checklistID == id }, sort: \Todo.order)
    }

    private var shownItems: [Todo] { items.filter { !(hideDone && $0.isDone) } }

    var body: some View {
        List {
            header.brutalRow(top: 10, bottom: 10)
            if editing { editor.brutalRow() }
            ForEach(shownItems) { item in
                ChecklistItemRow(item: item)
                    .brutalRow(top: 3, bottom: 5)
                    .swipeActions {
                        Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                    }
            }
            .onMove(perform: move)
            QuickAddField(prompt: "Add an item", text: $newText, onSubmit: add)
                .brutalRow(top: 10, bottom: 10)
            Color.clear.frame(height: 40).brutalRow()
        }
        .brutalList()
        .navigationTitle(list.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Hide ticked items", isOn: $hideDone)
                    Toggle("Edit checklist", isOn: $editing)
                    Button("Untick everything") { untickAll() }
                    Button { showLinks = true } label: { Label("Links", systemImage: "link") }
                    Button("Delete checklist", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Palette.ink)
                }
            }
        }
        .navigationDestination(isPresented: $showLinks) {
            LinksScreen(record: .checklist(list), title: list.displayTitle)
        }
        .confirmationDialog("Delete \(list.displayTitle) and its items?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteList)
        }
    }

    private var header: some View {
        let done = items.filter(\.isDone).count
        return BrutalCard(fill: list.areaValue.accent.color.opacity(0.35)) {
            HStack {
                Chip(text: list.phaseValue.title, accent: .lime)
                Chip(text: list.areaValue.title, accent: list.areaValue.accent, symbol: list.areaValue.symbol)
                Spacer()
                Text("\(done)/\(items.count)").font(Typeface.heading(22)).foregroundStyle(Palette.ink)
            }
            if !list.desc.isEmpty && !editing {
                Text(list.desc).font(Typeface.body(15)).foregroundStyle(Palette.ink)
            }
            BrutalProgress(value: items.isEmpty ? 0 : Double(done) / Double(items.count), accent: .lime)
        }
    }

    private var editor: some View {
        BrutalCard {
            TextField("Title", text: $list.title).textFieldStyle(.brutal)
            TextField("Description", text: $list.desc, axis: .vertical).textFieldStyle(.brutal)
            HStack {
                Picker("Phase", selection: Binding(get: { list.phaseValue }, set: { list.phaseValue = $0 })) {
                    ForEach(ChecklistPhase.allCases) { Text($0.title).tag($0) }
                }
                Spacer()
                Picker("Area", selection: Binding(get: { list.areaValue }, set: { list.areaValue = $0 })) {
                    ForEach(Area.allCases) { Text($0.title).tag($0) }
                }
            }
            .tint(Palette.ink)
            Toggle("Archived", isOn: $list.archived).tint(Accent.green.color)
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
        ctx.insert(item)
        newText = ""
    }

    private func untickAll() {
        for item in items where item.isDone { item.setDone(false) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = shownItems
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.order = Double(index + 1) }
    }

    private func deleteList() {
        let doomed = list
        let doomedItems = items
        let context = ctx
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for item in doomedItems { Store.delete(item, in: context) }
            Store.delete(doomed, in: context)
        }
    }
}

/// One checklist item: tick box and text; tap the text to open it as a task.
private struct ChecklistItemRow: View {
    let item: Todo

    var body: some View {
        CardLink {
            TaskDetail(task: item)
        } label: {
            HStack(spacing: Metrics.m) {
                TaskCheckbox(task: item)
                Text(item.displayTitle)
                    .font(Typeface.body(16, weight: .medium))
                    .foregroundStyle(item.isDone ? Palette.muted : Palette.ink)
                    .strikethrough(item.isDone)
                Spacer(minLength: 0)
                if let due = item.dueDate {
                    Text(shortDate(due))
                        .font(Typeface.body(12, weight: .semibold))
                        .foregroundStyle(item.isOverdue ? Palette.danger : Palette.muted)
                }
            }
            .padding(.horizontal, Metrics.m)
            .padding(.vertical, 10)
            .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall, border: Metrics.borderThin)
        }
    }
}

/// The Links section on its own screen, for screens that aren't a Form.
struct LinksScreen: View {
    let record: AnyRecord
    let title: String

    var body: some View {
        Form {
            LinksSection(record: record)
        }
        .brutalForm()
        .navigationTitle("Links")
        .navigationBarTitleDisplayMode(.inline)
    }
}
