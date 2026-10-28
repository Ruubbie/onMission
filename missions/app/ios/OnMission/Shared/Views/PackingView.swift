import SwiftUI
import SwiftData

/// The segments on the Packing page. The personal item rides with the carry-on; buy-there and
/// leave-behind share Other.
enum PackStop: String, CaseIterable, Hashable {
    case checked, carry, ship, other

    var title: String {
        switch self {
        case .checked: "Checked"
        case .carry: "Carry-on"
        case .ship: "Ship"
        case .other: "Other"
        }
    }

    /// The hand line on the poster.
    var name: String {
        switch self {
        case .checked: "Checked bag"
        case .carry: "Carry-on"
        case .ship: "Shipping box"
        case .other: "Buy there, leave behind"
        }
    }

    /// Where a new item from this segment goes.
    var bag: Bag {
        switch self {
        case .checked: .checked
        case .carry: .carryOn
        case .ship: .ship
        case .other: .buyThere
        }
    }

    func contains(_ bag: Bag) -> Bool {
        switch self {
        case .checked: bag == .checked
        case .carry: bag == .carryOn || bag == .personal
        case .ship: bag == .ship
        case .other: bag == .buyThere || bag == .leave
        }
    }
}

extension PackingItem {
    var kilos: Double { Double(weightGrams * max(quantity, 1)) / 1000 }
}

private func kg(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
}

// MARK: - Packing (handoff §7): how packed the bag is, items fly into the suitcase

struct PackingPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Query(sort: [SortDescriptor(\PackingItem.order), SortDescriptor(\PackingItem.name)]) private var items: [PackingItem]
    @State private var stop: PackStop = .checked
    @State private var slide = 0
    @State private var direction: CGFloat = 1
    @State private var level: Double = 0
    @State private var wobble = 0
    @State private var flight: Flight?
    @State private var caseFrame: CGRect = .zero
    @State private var showAll = false
    @State private var newName = ""
    @State private var landed = 0
    @State private var allPacked = 0

    struct Flight: Identifiable {
        let id = UUID()
        let from: CGPoint
        let to: CGPoint
    }

    private func inStop(_ s: PackStop) -> [PackingItem] { items.filter { s.contains($0.bagValue) } }

    private func fraction(_ list: [PackingItem]) -> Double {
        list.isEmpty ? 0 : Double(list.filter(\.packed).count) / Double(list.count)
    }

    var body: some View {
        let stops = PackStop.allCases.filter { $0 != .other || !inStop(.other).isEmpty }
        let segments = stops.map { s in Segments<PackStop>.Item(value: s, title: s.title, count: inStop(s).filter { !$0.packed }.count) }
        let list = inStop(stop)
        let open = list.filter { !$0.packed }
        let packedKg = list.filter(\.packed).reduce(0) { $0 + $1.kilos }
        let totalKg = list.reduce(0) { $0 + $1.kilos }
        let pct = Int((fraction(list) * 100).rounded())
        let done = !list.isEmpty && open.isEmpty
        let shown = showAll ? list : Array(open.prefix(4))
        Screen(posterHeight: 306, sheetTop: 10) {
            Hand(done ? "All packed!" : stop.name)
                .id(done ? "done" : stop.rawValue)
                .transition(.asymmetric(insertion: .offset(x: 20 * direction).combined(with: .opacity), removal: .opacity))
                .rise(0)
                .at(24, 106)
            Text("\(pct)%")
                .type(.disp(122))
                .contentTransition(.numericText(value: Double(pct)))
                .animation(.easeOut(duration: 0.8), value: pct)
                .lineLimit(1)
                .offset(y: FontMetrics.shift(size: 122, lineHeight: 0.8))
                .rise(1)
                .at(18, 138)
            CapLine(totalKg > 0 ? "\(kg(packedKg)) of \(kg(totalKg)) kg" : "\(list.filter(\.packed).count) of \(list.count) packed")
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.7), value: packedKg)
                .rise(2)
                .at(24, 272)
            Suitcase(level: level, wobble: wobble)
                .background {
                    GeometryReader { g in
                        Color.clear
                            .onAppear { caseFrame = g.frame(in: .global) }
                            .onChange(of: g.frame(in: .global)) { _, f in caseFrame = f }
                    }
                }
                .at(244, 108)
        } sheet: {
            Segments(items: segments, selection: $stop, tight: true)
            SheetScroll {
                Group {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                        PackRow(item: item, rule: index < shown.count - 1) { start in tick(item, from: start) }
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                    if !showAll && open.count > 4 {
                        MoreNote(text: "+\(open.count - 4) more to pack")
                    }
                    if list.isEmpty {
                        EmptyRow(title: "Nothing here yet", message: "Add what goes in, below or with the +.")
                    } else if open.isEmpty && !showAll {
                        EmptyRow(title: "All packed!", message: "Zip it up. Weigh it once more before you go.")
                    }
                }
                .slideIn(slide, direction: direction)
                FormBlock("") {
                    FieldRow {
                        AnimatedIcon(.plus, size: 18).foregroundStyle(Palette.ink).frame(width: 22)
                        TextField("", text: $newName, prompt: Text("Add to \(stop.title.lowercased())").foregroundStyle(Palette.inkFaint))
                            .type(.bodyBold)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                    ActionRow(title: showAll ? "Show what's left" : "Show everything · \(list.count)", icon: .list) {
                        withAnimation(Motion.fold.rm) { showAll.toggle() }
                    }
                    if list.contains(where: \.packed) {
                        ActionRow(title: "Unpack everything", icon: .undo) {
                            withAnimation(Motion.fold.rm) { for i in list { i.packed = false } }
                        }
                    }
                }
            }
        }
        .overlay {
            GeometryReader { geo in
                if let flight {
                    let o = geo.frame(in: .global).origin
                    FlyingDot(from: CGPoint(x: flight.from.x - o.x, y: flight.from.y - o.y),
                              to: CGPoint(x: flight.to.x - o.x, y: flight.to.y - o.y))
                        .id(flight.id)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            if items.isEmpty == false, inStop(.checked).isEmpty, let first = stops.first(where: { !inStop($0).isEmpty }) {
                stop = first
            }
            let target = fraction(inStop(stop))
            Motion.after(0.38) { withAnimation(.spring(k: 120, c: 13).rm) { level = target } }
        }
        .onChange(of: stop) { old, new in
            direction = Segments<PackStop>.direction(from: old, to: new, in: segments)
            slide += 1
            showAll = false
            withAnimation(.spring(k: 120, c: 13).rm) { level = fraction(inStop(new)) }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: landed)
        .sensoryFeedback(.success, trigger: allPacked)
        .captureContext(.packing)
    }

    /// The ring ticks, a dot flies in an arc into the suitcase, the suitcase wobbles, the level rises
    /// and the row folds.
    private func tick(_ item: PackingItem, from start: CGPoint?) {
        if !item.packed, !reduce, let start, caseFrame != .zero {
            flight = Flight(from: start, to: CGPoint(x: caseFrame.midX, y: caseFrame.minY + caseFrame.height * 0.6))
        }
        let s = stop
        Motion.after(item.packed ? 0 : 0.6) {
            wobble += 1
            landed += 1
            withAnimation(Motion.fold.rm) { item.packed.toggle() }
            let list = inStop(s)
            withAnimation(.spring(k: 120, c: 13).rm) { level = fraction(list) }
            if !list.isEmpty && list.allSatisfy(\.packed) {
                allPacked += 1
                router.showToast("\(s.name) is packed")
            }
            Motion.after(0.1) { flight = nil }
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let item = PackingItem()
        item.name = name
        item.bagValue = stop.bag
        item.order = (items.map(\.order).max() ?? 0) + 1
        withAnimation(Motion.arrive.rm) { ctx.insert(item) }
        newName = ""
        withAnimation(.spring(k: 120, c: 13).rm) { level = fraction(inStop(stop) + [item]) }
    }
}

/// An item: a ring to pack it, its name and category, and its weight.
private struct PackRow: View {
    @Environment(Router.self) private var router
    let item: PackingItem
    var rule = true
    let tick: (CGPoint?) -> Void
    @State private var ticked = false

    var body: some View {
        Row(rule: rule) {
            RingButton(ticked: ticked || item.packed, label: "Packed") {
                let start = TouchPoint.last
                TouchPoint.last = nil
                if !item.packed { ticked = true }
                tick(start)
            }
            RowText(title: item.quantity > 1 ? "\(item.quantity)× \(item.displayTitle)" : item.displayTitle,
                    subtitle: item.category, struck: ticked || item.packed)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.record(.packing(item))) }
            if item.weightGrams > 0 {
                WhenText(text: "\(kg(item.kilos)) kg")
            }
        }
        .onChange(of: item.packed) { _, now in if !now { ticked = false } }
        .accessibilityElement(children: .combine)
        .accessibilityAction { router.push(.record(.packing(item))) }
        .accessibilityAction(named: item.packed ? "Unpack" : "Pack") { tick(nil) }
    }
}

/// The suitcase: its outline, and a wavy level that springs up as things go in.
private struct Suitcase: View {
    let level: Double
    let wobble: Int

    var body: some View {
        Clock(trigger: wobble, duration: 0.48) { t in
            let p = t / 0.48
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Wave(level: level, closed: true).fill(Palette.sage.opacity(0.55))
                    Wave(level: level, closed: false).stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round))
                }
                .frame(width: 140, height: 272, alignment: .topLeading)
                .clipShape(SVGShape(d: SVG.rect(12, 62, 116, 186, rx: 16)))
                LineArt(drawing: Art.suitcase)
            }
            .frame(width: 140, height: 272, alignment: .topLeading)
            .rotationEffect(.degrees(p < 1 ? kf(p, [0, -3, 2, 0]) : 0), anchor: .bottom)
            .offset(y: p < 1 ? kf(p, [0, 2, 0, 0]) : 0)
        }
        .accessibilityElement()
        .accessibilityLabel("Suitcase, \(Int((level * 100).rounded())) percent packed")
    }
}

private struct Wave: Shape {
    var level: Double
    let closed: Bool

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let y = 248 - CGFloat(level) * 186
        var p = Path()
        p.move(to: CGPoint(x: 0, y: y))
        p.addCurve(to: CGPoint(x: 70, y: y), control1: CGPoint(x: 30, y: y - 6), control2: CGPoint(x: 50, y: y + 6))
        p.addCurve(to: CGPoint(x: 140, y: y), control1: CGPoint(x: 90, y: y - 6), control2: CGPoint(x: 110, y: y - 6))
        if closed {
            p.addLine(to: CGPoint(x: 140, y: 272))
            p.addLine(to: CGPoint(x: 0, y: 272))
            p.closeSubpath()
        }
        return p
    }
}

/// An ink dot with a paper ring, flying in an arc (640ms).
private struct FlyingDot: View {
    let from: CGPoint
    let to: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Palette.ink)
            .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 2))
            .frame(width: 16, height: 16)
            .modifier(ArcFlight(from: from, to: to, progress: progress))
            .onAppear {
                withAnimation(.curve(0.5, 0, 0.5, 1, 0.64)) { progress = 1 }
            }
    }
}

/// Moves a view from `from` to `to` in an arc `height` tall, shrinking a little on the way.
struct ArcFlight: GeometryEffect {
    let from: CGPoint
    let to: CGPoint
    var progress: CGFloat
    var height: CGFloat = 120

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = from.x + (to.x - from.x) * progress
        let y = from.y + (to.y - from.y) * progress - sin(progress * .pi) * height
        let k = 1 - 0.45 * progress
        let t = CGAffineTransform(translationX: x - size.width / 2, y: y - size.height / 2)
            .scaledBy(x: k, y: k)
        return ProjectionTransform(t)
    }
}

// MARK: - One item

struct PackingDetail: View {
    @Bindable var item: PackingItem

    var body: some View {
        DetailPage(aside: item.bagValue.title, title: item.displayTitle, cap: item.packed ? "Packed" : "Not packed yet") {
            FormBlock("Item") {
                TextRow("What", text: $item.name)
                ToggleRow("Packed", isOn: $item.packed)
                SelectRow("Bag", selection: Binding(get: { item.bagValue }, set: { item.bagValue = $0 })) {
                    ForEach(Bag.allCases) { Text($0.title).tag($0) }
                }
                StepperRow(title: "Quantity", value: $item.quantity, range: 1...99)
                LabeledRow("Weight (grams, each)") {
                    TextField("0", value: $item.weightGrams, format: .number)
                        .type(TypeStyle(size: 15.5, wght: 650, relativeTo: .body))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                }
                TextRow("Category (clothes, tech, papers…)", text: $item.category)
            }
            FormBlock("Notes") {
                TextRow("Notes", text: $item.notes, vertical: true, lines: 2...8)
            }
            LinksBlock(record: .packing(item))
            DeleteButton(item: item)
        }
        .captureContext(.packing, linkTo: .packing(item))
    }
}
