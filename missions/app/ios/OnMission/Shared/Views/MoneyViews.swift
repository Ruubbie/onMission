import SwiftUI
import SwiftData

// MARK: - Budget (handoff §7): what's left over, and a scale that tips

struct BudgetPage: View {
    enum Mode: Hashable { case month, setup }

    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \BudgetEntry.order) private var entries: [BudgetEntry]
    @Query private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var sells: [SellItem]
    @Query private var settingsList: [MissionSettings]
    @State private var mode: Mode = .month
    @State private var slide = 0
    @State private var direction: CGFloat = 1
    @State private var tilt: Double = 0

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: [], partners: partners, gifts: gifts, budget: entries,
                 sells: sells, packing: [], documents: [])
    }

    private func eur(_ e: BudgetEntry) -> Int { Insights.eurCents(e.amountCents, e.currency, settings) }

    /// Monthly: what comes in (partners and monthly income lines) and what goes out.
    private var monthIn: Int {
        insights.committedMonthlyCents
            + entries.filter { $0.kindValue == .income && $0.isMonthly }.reduce(0) { $0 + eur($1) }
    }

    /// The scale leans toward the heavier side: ±60° times the difference, at most 18°.
    private func lean(_ mode: Mode) -> Double {
        let i = insights
        let (a, b): (Int, Int) = mode == .month ? (monthIn, i.monthlyBudgetCents) : (i.setupCoveredCents, i.setupBudgetCents)
        let heavier = max(a, b)
        guard heavier > 0 else { return 0 }
        return min(max(Double(b - a) / Double(heavier) * 60, -18), 18)
    }

    var body: some View {
        let i = insights
        let segments = [Segments<Mode>.Item(value: .month, title: "Every month"),
                        Segments<Mode>.Item(value: .setup, title: "Before you go")]
        let left = monthIn - i.monthlyBudgetCents
        let aside = mode == .month ? (left >= 0 ? "Left over each month" : "Short each month") : (i.setupGapCents > 0 ? "Still to save" : "All covered!")
        let big = mode == .month ? (left >= 0 ? "+" : "−") + euros(abs(left)) : euros(i.setupGapCents)
        let cap = mode == .month ? "\(euros(monthIn)) in\n\(euros(i.monthlyBudgetCents)) out"
                                 : "\(euros(min(i.setupCoveredCents, i.setupBudgetCents))) saved\nof \(euros(i.setupBudgetCents))"
        Screen(posterHeight: 306, sheetTop: 10) {
            Group {
                Hand(aside).rise(0).at(24, 106)
                Lines(big, .disp(104), minScale: 0.5).frame(width: 340, alignment: .leading).rise(1).at(20, 140)
                CapLine(cap).rise(2).at(24, 254)
            }
            .id(mode)
            .transition(.asymmetric(insertion: .offset(y: 14).combined(with: .opacity), removal: .offset(y: -14).combined(with: .opacity)))
            // 206 keeps the OUT pan clear of the edge at full tilt.
            BalanceScale(tilt: tilt).at(206, 248)
        } sheet: {
            Segments(items: segments, selection: $mode)
            SheetScroll {
                Group {
                    if mode == .month { monthRows } else { setupRows }
                }
                .slideIn(slide, direction: direction)
                MoreLink(title: "Add a line") { newLine() }
            }
        }
        .onAppear {
            let target = lean(mode)
            Motion.after(0.45) { withAnimation(.spring(k: 60, c: 7).rm) { tilt = target } }
        }
        .onChange(of: mode) { old, new in
            direction = Segments<Mode>.direction(from: old, to: new, in: segments)
            slide += 1
            withAnimation(.spring(k: 60, c: 7).rm) { tilt = lean(new) }
        }
        .onChange(of: lean(mode)) { _, new in
            withAnimation(.spring(k: 60, c: 7).rm) { tilt = new }
        }
        .animation(.easeOut(duration: 0.35), value: mode)
    }

    @ViewBuilder
    private var monthRows: some View {
        let lines = entries.filter(\.isMonthly).sorted { ($0.kindValue == .income ? 0 : 1) < ($1.kindValue == .income ? 0 : 1) }
        let givers = partners.filter { $0.stageValue.countsAsSupport && $0.monthlyCents > 0 }.count
        Row(rule: !lines.isEmpty) {
            RowText(title: "Support from partners", subtitle: "In · \(givers) \(givers == 1 ? "person" : "people")")
            Amount(text: "+" + euros(insights.committedMonthlyCents), positive: true)
        }
        .onTapGesture { router.push(.allPeople) }
        ForEach(Array(lines.enumerated()), id: \.element.id) { index, e in
            BudgetRow(entry: e, cents: eur(e), rule: index < lines.count - 1)
        }
    }

    @ViewBuilder
    private var setupRows: some View {
        let lines = entries.filter { !$0.isMonthly }
        if lines.isEmpty {
            EmptyRow(title: "No one-off costs yet", message: "Flights, course fees, the visa, shipping boxes.")
        }
        ForEach(Array(lines.enumerated()), id: \.element.id) { index, e in
            BudgetRow(entry: e, cents: eur(e), rule: index < lines.count - 1)
        }
    }

    private func newLine() {
        let line = BudgetEntry()
        line.phaseValue = mode == .month ? .monthly : .setup
        line.recurrenceValue = mode == .month ? .monthly : .once
        line.order = (entries.map(\.order).max() ?? 0) + 1
        ctx.insert(line)
        router.push(.record(.budget(line)))
    }
}

/// An amount on the right of a row: incoming in sage.
private struct Amount: View {
    let text: String
    var positive = false

    var body: some View {
        Text(text)
            .type(TypeStyle(size: 16, wght: 650, relativeTo: .body))
            .foregroundStyle(positive ? Palette.sageDeep : Palette.ink)
            .monospacedDigit()
            .lineLimit(1)
            .frame(minWidth: 86, alignment: .trailing)
    }
}

private struct BudgetRow: View {
    @Environment(Router.self) private var router
    let entry: BudgetEntry
    let cents: Int
    var rule = true

    private var subtitle: String {
        let side = entry.kindValue == .income ? "In" : (entry.kindValue == .saving ? "Saving" : "Out")
        if entry.phaseValue == .setup && entry.kindValue == .expense {
            if entry.paid { return "\(side) · paid" }
            if let d = entry.date { return "Due \(shortDate(d, midSentence: true))" }
        }
        return entry.category.isEmpty ? side : "\(side) · \(entry.category)"
    }

    var body: some View {
        let positive = entry.kindValue == .income
        Row(rule: rule) {
            if entry.phaseValue == .setup && entry.kindValue == .expense && !entry.isMonthly {
                RingButton(ticked: entry.paid, label: "Paid") {
                    withAnimation(.easeOut(duration: 0.2)) { entry.paid.toggle() }
                }
            }
            RowText(title: entry.displayTitle, subtitle: subtitle, struck: entry.paid)
            Amount(text: (positive ? "+" : (entry.isMonthly ? "−" : "")) + euros(cents), positive: positive)
        }
        .contentShape(Rectangle())
        .onTapGesture { router.push(.record(.budget(entry))) }
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.record(.budget(entry))) }
    }
}

/// A balance scale labelled IN and OUT. The beam turns about its pivot and the pans hang level.
private struct BalanceScale: View, Animatable {
    var tilt: Double

    var animatableData: Double {
        get { tilt }
        set { tilt = newValue }
    }

    var body: some View {
        let a = tilt * .pi / 180
        let c = cos(a) * 65, s = sin(a) * 65
        ZStack(alignment: .topLeading) {
            LineArt(drawing: Drawing(width: 150, height: 140, paths: [.line("M75 26 L75 128"), .line("M50 132 L100 132")]))
            SVGShape(d: "M10 22 L140 22")
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round))
                .frame(width: 150, height: 140, alignment: .topLeading)
                .rotationEffect(.degrees(tilt), anchor: UnitPoint(x: 75.0 / 150, y: 22.0 / 140))
            pan(fill: Palette.paper).offset(x: 75 - c, y: 22 - s)
            pan(fill: Palette.flood).offset(x: 75 + c, y: 22 + s)
            Circle().fill(Palette.paper).overlay(Circle().stroke(Palette.ink, lineWidth: Metrics.line))
                .frame(width: 10, height: 10).offset(x: 70, y: 17)
            label("IN").position(x: 75 - c, y: 22 - s + 70)
            label("OUT").position(x: 75 + c, y: 22 + s + 70)
        }
        .frame(width: 150, height: 140, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// A pan hanging from (0, 0).
    private func pan(fill: Color) -> some View {
        ZStack(alignment: .topLeading) {
            SVGShape(d: "M24 0 L6 44 M24 0 L42 44")
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round))
            SVGShape(d: "M0 44 C 0 60, 48 60, 48 44 Z").fill(fill)
            SVGShape(d: "M0 44 C 0 60, 48 60, 48 44 Z")
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineJoin: .round))
        }
        .frame(width: 48, height: 60, alignment: .topLeading)
        .offset(x: -24)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .type(TypeStyle(size: 11, wght: 800, tracking: 0.14, relativeTo: nil))
            .foregroundStyle(Palette.ink)
            .fixedSize()
    }
}

struct BudgetEntryDetail: View {
    @Bindable var entry: BudgetEntry

    var body: some View {
        DetailPage(aside: "\(entry.kindValue.title) · \(entry.phaseValue.title)", title: entry.displayTitle,
                   cap: Money.text(entry.amountCents, entry.currency)) {
            FormBlock("Budget line") {
                TextRow("What", text: $entry.label)
                MoneyRow(title: "Amount", cents: $entry.amountCents, currency: entry.currency)
                SelectRow("Currency", selection: $entry.currency) {
                    Text("Euro").tag("EUR")
                    Text("NZ dollar").tag("NZD")
                }
                SelectRow("Kind", selection: Binding(get: { entry.kindValue }, set: { entry.kindValue = $0 })) {
                    ForEach(BudgetKind.allCases) { Text($0.title).tag($0) }
                }
                SelectRow("When", selection: Binding(get: { entry.phaseValue }, set: { entry.phaseValue = $0 })) {
                    ForEach(BudgetPhase.allCases) { Text($0.title).tag($0) }
                }
                SelectRow("Repeats", selection: Binding(get: { entry.recurrenceValue }, set: { entry.recurrenceValue = $0 })) {
                    ForEach(Recurrence.allCases) { Text($0.title).tag($0) }
                }
                if entry.phaseValue == .setup {
                    ToggleRow("Paid", isOn: $entry.paid)
                }
                OptionalDateRow(title: "Date", date: $entry.date)
                TextRow("Category (housing, travel, school…)", text: $entry.category)
            }
            FormBlock("Notes") {
                TextRow("Estimate? Where does the number come from?", text: $entry.notes, vertical: true, lines: 2...8)
            }
            LinksBlock(record: .budget(entry))
            DeleteButton(item: entry)
        }
    }
}

// MARK: - Selling (handoff §7): a SOLD stamp, and the price flies into the total

extension SellItem {
    /// "Bike 150" or "Bike €150,50": the last word, if it's a number, is the asking price.
    @discardableResult
    static func quick(_ text: String, _ ctx: ModelContext) -> SellItem? {
        var words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        let item = SellItem()
        if let last = words.last, words.count > 1,
           let price = Double(last.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: ",", with: ".")) {
            item.askingCents = Money.cents(fromEuros: price)
            words.removeLast()
        }
        item.name = words.joined(separator: " ")
        item.statusValue = item.askingCents > 0 ? .toList : .decide
        ctx.insert(item)
        return item
    }

    /// Sets the status; selling it records the asking price as the price it went for.
    func set(_ s: SellStatus) {
        statusValue = s
        if s == .sold && soldCents == 0 { soldCents = askingCents }
    }

    /// "Listed on Marktplaats", "Reserved for Mark", "Not listed yet".
    var line: String {
        switch statusValue {
        case .decide: return "Sell, give away, keep or store?"
        case .toList: return "Not listed yet"
        case .listed: return platform.isEmpty ? "Listed" : "Listed on \(platform)"
        case .reserved: return buyer.isEmpty ? "Reserved" : "Reserved for \(buyer)"
        case .sold: return buyer.isEmpty ? "Sold" : "Sold to \(buyer)"
        default: return statusValue.title
        }
    }

    var onTheMarket: Bool { [.decide, .toList, .listed, .reserved].contains(statusValue) }
}

struct SellingPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Query(sort: \SellItem.name) private var items: [SellItem]
    @Query private var settingsList: [MissionSettings]
    @State private var swing = 0
    @State private var quick = ""
    @State private var flight: PriceFlight?
    @State private var totalFrame: CGRect = .zero
    @State private var stamped = 0
    /// The total shown, held back until the flying price lands.
    @State private var shownSold: Int?

    struct PriceFlight: Identifiable {
        let id = UUID()
        let text: String
        let from: CGPoint
        let to: CGPoint
    }

    var body: some View {
        let settings = settingsList.first ?? MissionSettings()
        let sold = items.filter { $0.statusValue == .sold }.reduce(0) { $0 + Insights.eurCents($1.soldCents, $1.currency, settings) }
        let market = items.filter(\.onTheMarket)
        let listed = items.filter { $0.statusValue == .listed || $0.statusValue == .reserved }.count
        let total = shownSold ?? sold
        Screen(posterHeight: 306) {
            Hand("Selling up").rise(0).at(24, 106)
            Text(euros(total))
                .type(.disp(104))
                .contentTransition(.numericText(value: Double(total)))
                .animation(.easeOut(duration: 0.7), value: total)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 240, alignment: .leading)
                .offset(y: FontMetrics.shift(size: 104, lineHeight: 0.88))
                .background {
                    GeometryReader { g in
                        Color.clear
                            .onAppear { totalFrame = g.frame(in: .global) }
                            .onChange(of: g.frame(in: .global)) { _, f in totalFrame = f }
                    }
                }
                .rise(1)
                .at(20, 140)
            CapLine("Sold so far\n\(listed) \(listed == 1 ? "thing" : "things") listed").rise(2).at(24, 252)
            PriceTag(swing: swing).at(262, 204)
        } sheet: {
            SheetScroll {
                SectionHeader("On the market", count: market.count)
                ForEach(Array(market.enumerated()), id: \.element.id) { index, item in
                    SellRow(item: item, rule: index < market.count - 1) { sell(item, before: sold, settings: settings) }
                        .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                }
                if market.isEmpty {
                    EmptyRow(title: "Nothing on the market", message: "Add what you own below: \"Bike 150\" sets the price.")
                }
                FieldRow {
                    AnimatedIcon(.plus, size: 18).foregroundStyle(Palette.ink).frame(width: 22)
                    TextField("", text: $quick, prompt: Text("Something you own: Bike 150").foregroundStyle(Palette.inkFaint))
                        .type(.bodyBold)
                        .submitLabel(.done)
                        .onSubmit {
                            withAnimation(Motion.arrive.rm) { if SellItem.quick(quick, ctx) != nil { quick = "" } }
                        }
                }
                MoreLink(title: "Everything you own · \(items.count)") { router.push(.sellAll) }
            }
        }
        .overlay {
            GeometryReader { geo in
                if let flight {
                    let o = geo.frame(in: .global).origin
                    FlyingPrice(text: flight.text,
                                from: CGPoint(x: flight.from.x - o.x, y: flight.from.y - o.y),
                                to: CGPoint(x: flight.to.x - o.x, y: flight.to.y - o.y))
                        .id(flight.id)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear { Motion.after(0.5) { swing += 1 } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .captureContext(.sell)
    }

    /// The stamp lands, the price flies up into the total, the total counts up, the tag swings, the row folds.
    private func sell(_ item: SellItem, before: Int, settings: MissionSettings) {
        stamped += 1
        let start = TouchPoint.last
        TouchPoint.last = nil
        let price = Insights.eurCents(item.askingCents, item.currency, settings)
        shownSold = before
        Motion.after(0.26) {
            if !reduce, let start, totalFrame != .zero {
                flight = PriceFlight(text: euros(price), from: start, to: CGPoint(x: totalFrame.minX + 60, y: totalFrame.midY))
            }
        }
        Motion.after(0.82) {
            shownSold = before + price
            swing += 1
            flight = nil
        }
        Motion.after(1.47) {
            withAnimation(Motion.fold.rm) { item.set(.sold) }
            shownSold = nil
            router.showToast("\(item.displayTitle) sold")
        }
    }
}

/// An item on the market: its price, and Sold (or List, while it isn't listed yet).
private struct SellRow: View {
    @Environment(Router.self) private var router
    let item: SellItem
    var rule = true
    let sold: () -> Void
    @State private var stamp = false
    @State private var bump = 0
    @State private var listPlay = 0

    var body: some View {
        Row(rule: rule) {
            RowText(title: item.displayTitle, subtitle: item.line)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.record(.sell(item))) }
            if item.askingCents > 0 {
                WhenText(text: Money.text(item.askingCents, item.currency))
            }
            if item.statusValue == .decide || item.statusValue == .toList {
                Button {
                    listPlay += 1
                    withAnimation(.easeOut(duration: 0.2)) { item.set(.listed) }
                    router.showToast("\(item.displayTitle) is listed")
                } label: { Text("List") }
                .buttonStyle(.outlinedSmall)
            } else {
                Button {
                    guard !stamp else { return }
                    withAnimation(.curve(0.6, 0, 0.9, 0.6, 0.26).rm) { stamp = true }
                    Motion.after(0.26) { bump += 1 }
                    sold()
                } label: { Text("Sold") }
                .buttonStyle(.filledSmall)
                .disabled(stamp)
            }
        }
        .overlay(alignment: .leading) {
            if stamp {
                Text("Sold")
                    .type(TypeStyle(size: 30, wdth: 75, wght: 820, tracking: -0.01, uppercase: true, relativeTo: nil))
                    .foregroundStyle(Palette.coral)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: Metrics.stampRadius).fill(Palette.paper.opacity(0.9)))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.stampRadius).strokeBorder(Palette.coral, lineWidth: 3))
                    .rotationEffect(.degrees(-9))
                    .offset(x: 92)
                    .transition(.asymmetric(insertion: .scale(scale: 1.9).combined(with: .opacity), removal: .identity))
                    .allowsHitTesting(false)
            }
        }
        .keyframeAnimator(initialValue: CGFloat(0), trigger: bump) { view, y in
            view.offset(y: y)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(2, duration: 0.085)
                LinearKeyframe(0, duration: 0.085)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.record(.sell(item))) }
    }
}

/// The swinging price tag.
private struct PriceTag: View {
    let swing: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            Clock(trigger: swing, duration: 1.6) { t in
                let p = t < 1.6 ? Ease.easeInOut(t / 1.6) : 1
                ZStack(alignment: .topLeading) {
                    LineArt(drawing: Self.tag)
                    Text("€")
                        .type(TypeStyle(size: 42, wght: 820, relativeTo: nil))
                        .foregroundStyle(Palette.ink)
                        .position(x: 55, y: 110)
                }
                .frame(width: 110, height: 160, alignment: .topLeading)
                .rotationEffect(.degrees(kf(p, [0, 12, -8, 5, -2, 0])), anchor: UnitPoint(x: 0.5, y: 6.0 / 160))
            }
            Circle().fill(Palette.paper).overlay(Circle().stroke(Palette.ink, lineWidth: Metrics.line))
                .frame(width: 9, height: 9).offset(x: 50.5, y: 1.5)
        }
        .frame(width: 110, height: 160, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    static let tag = Drawing(width: 110, height: 160, paths: [
        .line("M55 6 L55 46"),
        .flood("M28 56 L55 38 L82 56 L82 146 C 82 151, 78 154, 73 154 L37 154 C 32 154, 28 151, 28 146 Z"),
        .line(SVG.circle(55, 56, 5)),
    ])
}

/// The sold price, flying up into the total.
private struct FlyingPrice: View {
    let text: String
    let from: CGPoint
    let to: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        Text(text)
            .type(TypeStyle(size: 20, wdth: 75, wght: 820, relativeTo: nil))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.paper))
            .fixedSize()
            .modifier(ArcFlight(from: from, to: to, progress: progress, height: 60))
            .onAppear {
                withAnimation(.curve(0.5, 0, 0.5, 1, 0.56)) { progress = 1 }
            }
    }
}

// MARK: - Everything you own

struct SellAllPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \SellItem.name) private var items: [SellItem]
    @State private var quick = ""

    var body: some View {
        let settled = items.filter { $0.statusValue.isSettled }.count
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Everything you own").rise(0).at(24, 106)
            Lines("\(items.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine("\(settled) with a place\n\(items.count - settled) to decide").rise(2).at(24, 292)
            // The traveller photographing something to sell.
            Picture(.travellerPhoto, height: 226).rise(3).at(276, 110)
        } sheet: {
            SheetScroll {
                FieldRow {
                    AnimatedIcon(.plus, size: 18).foregroundStyle(Palette.ink).frame(width: 22)
                    TextField("", text: $quick, prompt: Text("Something you own: Bike 150").foregroundStyle(Palette.inkFaint))
                        .type(.bodyBold)
                        .submitLabel(.done)
                        .onSubmit {
                            withAnimation(Motion.arrive.rm) { if SellItem.quick(quick, ctx) != nil { quick = "" } }
                        }
                }
                ForEach(SellStatus.allCases) { status in
                    let rows = items.filter { $0.statusValue == status }
                    if !rows.isEmpty {
                        SectionHeader(status.title, count: rows.count).padding(.top, 18)
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                            Button { router.push(.record(.sell(item))) } label: {
                                Row(rule: index < rows.count - 1) {
                                    RowText(title: item.displayTitle, subtitle: item.line)
                                    let cents = item.statusValue == .sold ? item.soldCents : item.askingCents
                                    if cents > 0 { WhenText(text: Money.text(cents, item.currency)) }
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                ForEach(SellStatus.allCases) { s in
                                    Button(s.title) { withAnimation(Motion.fold.rm) { item.set(s) } }
                                }
                                Button("Delete", role: .destructive) { Store.delete(item, in: ctx) }
                            }
                        }
                    }
                }
                if items.isEmpty {
                    EmptyRow(title: "Nothing here yet", message: "Everything you own gets a place: sell, give away, keep for your luggage, or storage.")
                }
            }
        }
        .captureContext(.sell)
    }
}

struct SellDetail: View {
    @Bindable var item: SellItem

    var body: some View {
        let cents = item.statusValue == .sold ? item.soldCents : item.askingCents
        DetailPage(aside: item.statusValue.title, title: item.displayTitle,
                   cap: cents > 0 ? Money.text(cents, item.currency) : "No price yet") {
            FormBlock("Selling") {
                TextRow("What", text: $item.name)
                SelectRow("Status", selection: Binding(get: { item.statusValue }, set: { item.set($0) })) {
                    ForEach(SellStatus.allCases) { Text($0.title).tag($0) }
                }
                MoneyRow(title: "Asking", cents: $item.askingCents, currency: item.currency)
                if item.statusValue == .sold {
                    MoneyRow(title: "Sold for", cents: $item.soldCents, currency: item.currency)
                }
                TextRow("Where (Marktplaats, Vinted, a friend…)", text: $item.platform)
                TextRow("Listing link", text: $item.listingURL, keyboard: .URL, plain: true)
                if let url = URL(string: item.listingURL), !item.listingURL.isEmpty, url.scheme != nil {
                    Link(destination: url) {
                        FieldRow {
                            AnimatedIcon(.link, size: 20).foregroundStyle(Palette.ink)
                            Text("Open listing").type(.bodyBold).foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            FormBlock("Handover") {
                TextRow("Buyer", text: $item.buyer)
                OptionalDateRow(title: "Pickup", date: $item.pickupDate)
                TextRow("Where it is now", text: $item.location)
                TextRow("Notes", text: $item.notes, vertical: true, lines: 2...8)
            }
            LinksBlock(record: .sell(item))
            DeleteButton(item: item)
        }
        .captureContext(.sell, linkTo: .sell(item))
    }
}
