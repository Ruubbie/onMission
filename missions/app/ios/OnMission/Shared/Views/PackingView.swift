import SwiftUI
import SwiftData

/// What goes in which bag, and what's packed.
struct PackingView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\PackingItem.order), SortDescriptor(\PackingItem.name)]) private var items: [PackingItem]
    @State private var quick = ""
    @State private var bag: Bag = .checked
    @State private var hidePacked = false
    @State private var opened: PackingItem?

    var body: some View {
        List {
            PackingSummary(items: items).brutalRow(top: 10, bottom: 8)
            addRow.brutalRow(top: 6, bottom: 6)
            ForEach(Bag.allCases) { b in
                let all = items.filter { $0.bagValue == b }
                let shown = all.filter { !(hidePacked && $0.packed) }
                if !all.isEmpty {
                    SectionHeader(b.title, count: all.count, accent: .lime)
                        .brutalRow(top: 14, bottom: 0)
                    Text(bagLine(all))
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                        .brutalRow(top: 0, bottom: 4)
                    ForEach(shown) { item in
                        CardLink { PackingDetail(item: item) } label: { PackingRow(item: item) }
                            .brutalRow(top: 3, bottom: 5)
                            .swipeActions {
                                Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                            }
                            .contextMenu {
                                Menu("Move to") {
                                    ForEach(Bag.allCases) { target in
                                        Button(target.title) { item.bagValue = target }
                                    }
                                }
                                Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                            }
                    }
                }
            }
            if items.isEmpty {
                BrutalEmptyState(symbol: "suitcase.fill", title: "Nothing to pack yet",
                                 message: "Add what goes in your checked bag, carry-on, what you ship and what you buy there.",
                                 accent: .lime)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .navigationTitle("Packing")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Hide packed items", isOn: $hidePacked)
                    Button("Unpack everything") { for i in items { i.packed = false } }
                } label: {
                    IconTile(symbol: "ellipsis", size: 36)
                }
                .toggleStyle(.automatic)
            }
        }
        .addButton(newItem)
        .navigationDestination(item: $opened) { PackingDetail(item: $0) }
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            QuickAddField(prompt: "Add to \(bag.title.lowercased())", text: $quick, onSubmit: add)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Bag.allCases) { b in
                        FilterChip(text: b.title, accent: .lime, selected: bag == b) { bag = b }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func bagLine(_ list: [PackingItem]) -> String {
        let packed = list.filter(\.packed).count
        let grams = list.reduce(0) { $0 + $1.weightGrams * max($1.quantity, 1) }
        var text = "\(packed) of \(list.count) packed"
        if grams > 0 { text += " · \((Double(grams) / 1000).formatted(.number.precision(.fractionLength(1)))) kg" }
        return text
    }

    private func add() {
        let name = quick.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let item = PackingItem()
        item.name = name
        item.bagValue = bag
        item.order = (items.map(\.order).max() ?? 0) + 1
        ctx.insert(item)
        quick = ""
    }

    private func newItem() {
        let item = PackingItem()
        item.bagValue = bag
        item.order = (items.map(\.order).max() ?? 0) + 1
        ctx.insert(item)
        opened = item
    }
}

private struct PackingSummary: View {
    let items: [PackingItem]

    var body: some View {
        let packed = items.filter(\.packed).count
        BrutalCard(fill: Accent.lime.color) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(packed)/\(items.count)").font(Typeface.heading(30)).foregroundStyle(Palette.ink)
                Text("packed").font(Typeface.body(15, weight: .semibold)).foregroundStyle(Palette.ink)
            }
            BrutalProgress(value: items.isEmpty ? 0 : Double(packed) / Double(items.count), accent: .yellow)
        }
    }
}

private struct PackingRow: View {
    let item: PackingItem

    var body: some View {
        HStack(spacing: Metrics.m) {
            Button {
                withAnimation { item.packed.toggle() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(item.packed ? Palette.ink : Color.clear)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 5).fill(item.packed ? Accent.lime.color : Palette.paper))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: Metrics.border))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.packed ? "Packed" : "Not packed")
            VStack(alignment: .leading, spacing: 2) {
                Text(item.quantity > 1 ? "\(item.quantity)× \(item.displayTitle)" : item.displayTitle)
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(item.packed ? Palette.muted : Palette.ink)
                    .strikethrough(item.packed)
                if !item.category.isEmpty {
                    Text(item.category).font(Typeface.body(12)).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
            if item.weightGrams > 0 {
                Text("\(item.weightGrams) g").font(Typeface.body(12, weight: .semibold)).foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, Metrics.m)
        .padding(.vertical, 10)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall, border: Metrics.borderThin)
    }
}

struct PackingDetail: View {
    @Bindable var item: PackingItem

    var body: some View {
        Form {
            FormHeroRow(fill: Accent.lime.color) {
                TextField("What", text: $item.name)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                Toggle("Packed", isOn: $item.packed).tint(Palette.ink)
                    .font(Typeface.body(16, weight: .semibold))
            }
            Section {
                BrutalSelect("Bag", selection: Binding(get: { item.bagValue }, set: { item.bagValue = $0 })) {
                    ForEach(Bag.allCases) { Text($0.title).tag($0) }
                }
                BrutalStepper("Quantity: \(item.quantity)", value: $item.quantity, in: 1...99)
                LabeledContent("Weight (grams, each)") {
                    TextField("0", value: $item.weightGrams, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                TextField("Category (clothes, tech, papers…)", text: $item.category)
            } header: { FormHeader("Item") }
            Section {
                TextField("Notes", text: $item.notes, axis: .vertical).lineLimit(2...8)
            } header: { FormHeader("Notes") }
            LinksSection(record: .packing(item))
            Section { DeleteRecordButton(item: item) }
        }
        .brutalForm()
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
