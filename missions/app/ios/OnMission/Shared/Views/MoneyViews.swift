import SwiftUI
import SwiftData

// MARK: - Budget

struct BudgetView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \BudgetEntry.order) private var entries: [BudgetEntry]
    @Query private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var sells: [SellItem]
    @Query private var settingsList: [MissionSettings]
    @State private var opened: BudgetEntry?

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    var body: some View {
        let i = Insights(settings: settings, tasks: [], partners: partners, gifts: gifts, budget: entries,
                         sells: sells, packing: [], documents: [])
        List {
            MonthlyBudgetCard(insights: i, settings: settings).brutalRow(top: 10, bottom: 10)
            SetupBudgetCard(insights: i).brutalRow(top: 6, bottom: 10)
            ForEach(BudgetPhase.allCases) { phase in
                let lines = entries.filter { $0.phaseValue == phase }
                SectionHeader(phase.title, count: lines.count, accent: .green)
                    .brutalRow(top: 14, bottom: 2)
                ForEach(lines) { line in
                    CardLink { BudgetEntryDetail(entry: line) } label: { BudgetRow(entry: line, settings: settings) }
                        .brutalRow(top: 3, bottom: 5)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Store.delete(line, in: ctx) }
                        }
                }
                Button { newLine(phase) } label: {
                    Label("Add a line", systemImage: "plus")
                }
                .buttonStyle(.brutalCompact)
                .brutalRow(top: 6, bottom: 6)
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .navigationTitle("Budget")
        .addButton { newLine(.setup) }
        .navigationDestination(item: $opened) { BudgetEntryDetail(entry: $0) }
    }

    private func newLine(_ phase: BudgetPhase) {
        let line = BudgetEntry()
        line.phaseValue = phase
        line.recurrenceValue = phase == .monthly ? .monthly : .once
        line.order = (entries.map(\.order).max() ?? 0) + 1
        ctx.insert(line)
        opened = line
    }
}

private struct MonthlyBudgetCard: View {
    let insights: Insights
    let settings: MissionSettings

    var body: some View {
        let gap = insights.monthlyBudgetCents - insights.committedMonthlyCents
        BrutalCard(fill: Accent.green.color.opacity(0.25)) {
            Label("Every month", systemImage: "calendar")
                .font(Typeface.heading(18)).foregroundStyle(Palette.ink)
            StatLine(label: "Monthly need", value: euros(insights.monthlyBudgetCents))
            StatLine(label: "Committed by partners", value: euros(insights.committedMonthlyCents))
            StatLine(label: gap > 0 ? "Still to find" : "Above budget", value: euros(abs(gap)), bold: true)
            BrutalProgress(value: insights.monthlyBudgetCents > 0
                           ? Double(insights.committedMonthlyCents) / Double(insights.monthlyBudgetCents) : 0,
                           accent: gap <= 0 ? .green : .yellow)
            Text("Your target is \(euros(settings.supportMinimumMonthlyCents)) minimum, \(euros(settings.supportTargetMonthlyCents)) goal (Settings). NZ dollars are converted at \(settings.nzdPerEur.formatted()) per euro.")
                .font(Typeface.body(13)).foregroundStyle(Palette.ink)
        }
    }
}

private struct SetupBudgetCard: View {
    let insights: Insights

    var body: some View {
        BrutalCard {
            Label("Before you go", systemImage: "airplane.departure")
                .font(Typeface.heading(18)).foregroundStyle(Palette.ink)
            StatLine(label: "One-off costs", value: euros(insights.setupBudgetCents))
            StatLine(label: "Already paid", value: euros(insights.setupPaidCents))
            StatLine(label: "Sold so far", value: euros(insights.soldCents))
            StatLine(label: "One-off gifts", value: euros(insights.oneOffGiftCents))
            StatLine(label: "Gap", value: euros(insights.setupGapCents), bold: true)
            BrutalProgress(value: insights.setupBudgetCents > 0
                           ? Double(insights.setupCoveredCents) / Double(insights.setupBudgetCents) : 0,
                           accent: .green)
            Text("Sales and one-off gifts count towards these costs automatically.")
                .font(Typeface.body(13)).foregroundStyle(Palette.muted)
        }
    }
}

private struct BudgetRow: View {
    let entry: BudgetEntry
    let settings: MissionSettings

    private var kindAccent: Accent {
        switch entry.kindValue {
        case .income: return .green
        case .expense: return .pink
        case .saving: return .purple
        }
    }

    var body: some View {
        HStack(spacing: Metrics.m) {
            if entry.phaseValue == .setup && entry.kindValue == .expense {
                PaidBox(entry: entry)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.displayTitle)
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(entry.paid ? Palette.muted : Palette.ink)
                    .strikethrough(entry.paid)
                HStack(spacing: 6) {
                    Chip(text: entry.kindValue.title, accent: kindAccent)
                    if !entry.category.isEmpty {
                        Text(entry.category).font(Typeface.body(12)).foregroundStyle(Palette.muted)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.kindValue == .income ? "+" : "")\(Money.text(entry.amountCents, entry.currency))")
                    .font(Typeface.heading(15))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                if entry.currency != "EUR" {
                    Text("≈ \(euros(Insights.eurCents(entry.amountCents, entry.currency, settings)))")
                        .font(Typeface.body(11))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

private struct PaidBox: View {
    let entry: BudgetEntry

    var body: some View {
        Button {
            withAnimation { entry.paid.toggle() }
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(entry.paid ? Palette.ink : Color.clear)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 5).fill(entry.paid ? Accent.green.color : Palette.paper))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: Metrics.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.paid ? "Paid" : "Not paid")
    }
}

struct BudgetEntryDetail: View {
    @Bindable var entry: BudgetEntry

    var body: some View {
        Form {
            FormHeroRow(fill: Accent.green.color.opacity(0.25)) {
                TextField("What", text: $entry.label)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                Text(Money.text(entry.amountCents, entry.currency))
                    .font(Typeface.heading(30))
                    .foregroundStyle(Palette.ink)
            }
            Section {
                MoneyField(title: "Amount", cents: $entry.amountCents, currency: entry.currency)
                BrutalSelect("Currency", selection: $entry.currency) {
                    Text("Euro").tag("EUR")
                    Text("NZ dollar").tag("NZD")
                }
                BrutalSelect("Kind", selection: Binding(get: { entry.kindValue }, set: { entry.kindValue = $0 })) {
                    ForEach(BudgetKind.allCases) { Text($0.title).tag($0) }
                }
                BrutalSelect("When", selection: Binding(get: { entry.phaseValue }, set: { entry.phaseValue = $0 })) {
                    ForEach(BudgetPhase.allCases) { Text($0.title).tag($0) }
                }
                BrutalSelect("Repeats", selection: Binding(get: { entry.recurrenceValue }, set: { entry.recurrenceValue = $0 })) {
                    ForEach(Recurrence.allCases) { Text($0.title).tag($0) }
                }
                if entry.phaseValue == .setup {
                    Toggle("Paid", isOn: $entry.paid).tint(Accent.green.color)
                }
                OptionalDatePicker(title: "Date", date: $entry.date)
                TextField("Category (housing, travel, school…)", text: $entry.category)
            } header: { FormHeader("Budget line") }
            Section {
                TextField("Estimate? Where does the number come from?", text: $entry.notes, axis: .vertical)
                    .lineLimit(2...8)
            } header: { FormHeader("Notes") }
            LinksSection(record: .budget(entry))
            Section { DeleteRecordButton(item: entry) }
        }
        .brutalForm()
        .navigationTitle(entry.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Selling

struct SellView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \SellItem.name) private var items: [SellItem]
    @State private var opened: SellItem?
    @State private var quick = ""

    var body: some View {
        List {
            SellSummary(items: items).brutalRow(top: 10, bottom: 8)
            QuickAddField(prompt: "Something you own (\"Bike 150\" sets the price)", text: $quick, onSubmit: add)
                .brutalRow(top: 6, bottom: 6)
            ForEach(SellStatus.allCases) { status in
                let rows = items.filter { $0.statusValue == status }
                if !rows.isEmpty {
                    SectionHeader(status.title, count: rows.count, accent: status.accent)
                        .brutalRow(top: 14, bottom: 2)
                    ForEach(rows) { item in
                        CardLink { SellDetail(item: item) } label: { SellRow(item: item) }
                            .brutalRow(top: 3, bottom: 5)
                            .contextMenu {
                                ForEach(SellStatus.allCases) { s in
                                    Button(s.title) { SellDetail.setStatus(item, s) }
                                }
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                            }
                            .swipeActions(edge: .leading) {
                                if status != .sold {
                                    Button("Sold") { SellDetail.setStatus(item, .sold) }.tint(Palette.ok)
                                }
                            }
                    }
                }
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .navigationTitle("Selling")
        .addButton(newItem)
        .navigationDestination(item: $opened) { SellDetail(item: $0) }
    }

    private func newItem() {
        let item = SellItem()
        ctx.insert(item)
        opened = item
    }

    /// "Bike 150" or "Bike €150,50": the last word, if it's a number, is the asking price.
    private func add() {
        var words = quick.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return }
        let item = SellItem()
        if let last = words.last, words.count > 1,
           let price = Double(last.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: ",", with: ".")) {
            item.askingCents = Money.cents(fromEuros: price)
            words.removeLast()
        }
        item.name = words.joined(separator: " ")
        item.statusValue = item.askingCents > 0 ? .toList : .decide
        ctx.insert(item)
        quick = ""
    }
}

private struct SellSummary: View {
    let items: [SellItem]

    var body: some View {
        let sold = items.filter { $0.statusValue == .sold }.reduce(0) { $0 + $1.soldCents }
        let open = items.filter { !$0.statusValue.isSettled }
        let potential = open.reduce(0) { $0 + $1.askingCents }
        BrutalCard(fill: Accent.sand.color) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(euros(sold)).font(Typeface.heading(30)).foregroundStyle(Palette.ink)
                Text("sold so far").font(Typeface.body(15)).foregroundStyle(Palette.ink)
            }
            StatLine(label: "Still to sell (asking)", value: euros(potential))
            StatLine(label: "Not settled yet", value: "\(open.count) of \(items.count)")
            BrutalProgress(value: items.isEmpty ? 0 : Double(items.count - open.count) / Double(items.count), accent: .green)
            Text("Everything you own gets a place: sell, give away, keep for your luggage, or storage.")
                .font(Typeface.body(13)).foregroundStyle(Palette.ink)
        }
    }
}

private struct SellRow: View {
    let item: SellItem

    var body: some View {
        HStack(spacing: Metrics.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                let detail = [item.platform, item.buyer, item.pickupDate.map { "pickup \(shortDate($0))" } ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(Typeface.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            let cents = item.statusValue == .sold ? item.soldCents : item.askingCents
            if cents > 0 {
                Text(Money.text(cents, item.currency))
                    .font(Typeface.heading(15))
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
            }
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

struct SellDetail: View {
    @Bindable var item: SellItem

    static func setStatus(_ item: SellItem, _ s: SellStatus) {
        item.statusValue = s
        if s == .sold && item.soldCents == 0 { item.soldCents = item.askingCents }
    }

    var body: some View {
        Form {
            FormHeroRow(fill: Accent.sand.color) {
                TextField("What", text: $item.name)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                Chip(text: item.statusValue.title, accent: item.statusValue.accent)
            }
            Section {
                BrutalSelect("Status", selection: Binding(get: { item.statusValue }, set: { Self.setStatus(item, $0) })) {
                    ForEach(SellStatus.allCases) { Text($0.title).tag($0) }
                }
                MoneyField(title: "Asking", cents: $item.askingCents, currency: item.currency)
                if item.statusValue == .sold {
                    MoneyField(title: "Sold for", cents: $item.soldCents, currency: item.currency)
                }
                TextField("Where (Marktplaats, Vinted, a friend…)", text: $item.platform)
                TextField("Listing link", text: $item.listingURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let url = URL(string: item.listingURL), !item.listingURL.isEmpty, url.scheme != nil {
                    Link(destination: url) { Label("Open listing", systemImage: "safari") }
                }
            } header: { FormHeader("Selling") }
            Section {
                TextField("Buyer", text: $item.buyer)
                OptionalDatePicker(title: "Pickup", date: $item.pickupDate)
                TextField("Where it is now", text: $item.location)
                TextField("Notes", text: $item.notes, axis: .vertical).lineLimit(2...8)
            } header: { FormHeader("Handover") }
            LinksSection(record: .sell(item))
            Section { DeleteRecordButton(item: item) }
        }
        .brutalForm()
        .navigationTitle(item.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
