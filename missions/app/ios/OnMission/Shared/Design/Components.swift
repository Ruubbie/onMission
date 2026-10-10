import SwiftUI
import SwiftData

// The neo-brutalist building blocks: cream page, paper cards, thick ink outlines and hard
// (never blurred) ink shadows. Every screen is made from these.

// MARK: - The basic box: fill, ink outline, hard shadow

extension View {
    /// Paper (or any) fill, ink outline and a solid ink shadow offset to the bottom right.
    func brutalBox<S: Shape>(shape: S, fill: Color = Palette.paper, shadow: CGFloat = Metrics.shadow,
                             border: CGFloat = Metrics.border) -> some View {
        self
            .background {
                ZStack {
                    shape.fill(Palette.ink).offset(x: shadow, y: shadow)
                    shape.fill(fill)
                }
            }
            .overlay {
                shape.stroke(Palette.ink, lineWidth: border)
                    .padding(border / 2)
                    .allowsHitTesting(false)
            }
    }

    /// The same, with a rounded rectangle.
    func brutalBox(fill: Color = Palette.paper, radius: CGFloat = Metrics.radius, shadow: CGFloat = Metrics.shadow,
                   border: CGFloat = Metrics.border) -> some View {
        brutalBox(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), fill: fill, shadow: shadow, border: border)
    }

    /// The cream page behind a screen (also behind Lists and Forms).
    func brutalBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .toolbarBackground(Palette.background, for: .navigationBar)
    }

    /// A Form in the app's style: cream page, ink tint.
    func brutalForm() -> some View {
        self
            .brutalBackground()
            .tint(Palette.ink)
            .listRowBackground(Palette.paper)
            .listRowSeparatorTint(Palette.hairline)
            .listSectionSpacing(Metrics.xl)
    }

    /// A plain List whose rows are brutal cards.
    func brutalList() -> some View {
        self
            .listStyle(.plain)
            .brutalBackground()
            .environment(\.defaultMinListRowHeight, 1)
    }

    /// A row inside `brutalList()`: no separator, no grey background, room for the shadow.
    func brutalRow(top: CGFloat = 6, bottom: CGFloat = 8) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: Metrics.l, bottom: bottom, trailing: Metrics.l))
    }

    /// The floating yellow + on list screens.
    func addButton(_ action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            AboveTabBar { AddButton(action: action) }
        }
    }

    /// The floating yellow + that opens a menu.
    func addMenu<MenuContent: View>(@ViewBuilder _ content: @escaping () -> MenuContent) -> some View {
        overlay(alignment: .bottomTrailing) {
            AboveTabBar { Menu(content: content) { AddButtonLabel() } }
        }
    }
}

/// Places the + 20pt from the edges, above the floating tab bar.
private struct AboveTabBar<Content: View>: View {
    @Environment(\.floatingBarInset) private var barInset
    @ViewBuilder var content: Content

    var body: some View {
        content.padding(.trailing, 20).padding(.bottom, 20 + barInset)
    }
}

// MARK: - Cards

/// A paper card with an ink outline and a hard shadow.
struct BrutalCard<Content: View>: View {
    var fill: Color = Palette.paper
    var padding: CGFloat = Metrics.l
    var shadow: CGFloat = Metrics.shadow
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(fill: fill, shadow: shadow)
    }
}

/// A card with a coloured folder tab on top carrying the title. Used on Today and More.
struct FolderTabCard: View {
    let title: String
    let accent: Accent
    let symbol: String
    var count: String
    var subtitle: String = ""

    init(title: String, accent: Accent, symbol: String, count: String, subtitle: String = "") {
        self.title = title
        self.accent = accent
        self.symbol = symbol
        self.count = count
        self.subtitle = subtitle
    }

    init(title: String, accent: Accent, symbol: String, count: Int, subtitle: String = "") {
        self.init(title: title, accent: accent, symbol: symbol, count: "\(count)", subtitle: subtitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -Metrics.border) {
            FolderTab(title: title, accent: accent)
            FolderBody(accent: accent, symbol: symbol, count: count, subtitle: subtitle)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FolderTab: View {
    let title: String
    let accent: Accent
    private let height: CGFloat = 20 + 6 * 2

    var body: some View {
        Text(title)
            .font(Typeface.heading(14))
            .foregroundStyle(accent.onColor)
            .lineLimit(1)
            .padding(.leading, 12)
            .padding(.trailing, 12 + height * 0.6)
            .padding(.top, 6)
            .padding(.bottom, 6 + Metrics.border)
            .brutalBox(shape: FolderTabShape(), fill: accent.color, shadow: Metrics.shadow)
    }
}

/// A folder tab: straight left side, flat top, right side slanting outward going down.
/// The slant is 0.6 x the tab height, like the desktop card.
struct FolderTabShape: Shape {
    func path(in r: CGRect) -> Path {
        let slant = r.height * 0.6
        let tl = Metrics.radiusSmall
        let tr: CGFloat = 4
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.addQuadCurve(to: CGPoint(x: r.minX + tl, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - slant - tr, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - slant + tr * 0.5, y: r.minY + tr),
                       control: CGPoint(x: r.maxX - slant, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

private struct FolderBody: View {
    let accent: Accent
    let symbol: String
    let count: String
    let subtitle: String

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: Metrics.radius,
                               bottomTrailingRadius: Metrics.radius, topTrailingRadius: Metrics.radius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                AccentSquareIcon(symbol: symbol, accent: accent)
                Spacer(minLength: 4)
                Text(count)
                    .font(Typeface.heading(30))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Typeface.body(13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.m)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .brutalBox(shape: shape)
    }
}

/// An icon in a small accent-filled outlined square.
struct AccentSquareIcon: View {
    let symbol: String
    var accent: Accent = .yellow
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(accent.onColor)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous).fill(accent.color))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                    .strokeBorder(Palette.ink, lineWidth: Metrics.borderThin)
            )
    }
}

// MARK: - Buttons

/// Bold label in a filled, outlined box with a hard shadow. Pressing moves it into its shadow.
struct BrutalButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    /// Overrides the fill from `kind`.
    var fill: Color? = nil
    var compact: Bool = false

    private var background: Color {
        if let fill { return fill }
        switch kind {
        case .primary: return Accent.yellow.color
        case .secondary: return Palette.paper
        case .danger: return Palette.danger
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shadow = compact ? Metrics.shadowSmall : Metrics.shadow
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
        return configuration.label
            .font(Typeface.heading(compact ? 14 : 16))
            .foregroundStyle(kind == .danger ? Color.white : Palette.ink)
            .padding(.horizontal, compact ? 10 : 16)
            .padding(.vertical, compact ? 6 : 10)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: Metrics.border))
            .background(shape.fill(Palette.ink).offset(x: pressed ? 0 : shadow, y: pressed ? 0 : shadow))
            .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == BrutalButtonStyle {
    static var brutal: BrutalButtonStyle { BrutalButtonStyle(kind: .primary) }
    static var brutalSecondary: BrutalButtonStyle { BrutalButtonStyle(kind: .secondary) }
    static var brutalCompact: BrutalButtonStyle { BrutalButtonStyle(kind: .secondary, compact: true) }
}

/// Square press style used by the icon and add buttons.
struct BrutalSquarePressStyle: ButtonStyle {
    var fill: Color = Palette.paper
    var shadow: CGFloat = Metrics.shadowSmall
    var radius: CGFloat = Metrics.radiusSmall

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: Metrics.border))
            .background(shape.fill(Palette.ink).offset(x: pressed ? 0 : shadow, y: pressed ? 0 : shadow))
            .offset(x: pressed ? shadow : 0, y: pressed ? shadow : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// A square outlined icon button with a small hard shadow.
struct IconButton: View {
    let symbol: String
    var accent: Accent? = nil
    var size: CGFloat = 40
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(accent?.onColor ?? Palette.ink)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(BrutalSquarePressStyle(fill: accent?.color ?? Palette.paper))
        .accessibilityLabel(label.isEmpty ? symbol : label)
    }
}

/// The look of IconButton without the button, for Menu and ShareLink labels.
struct IconTile: View {
    let symbol: String
    var accent: Accent? = nil
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(accent?.onColor ?? Palette.ink)
            .frame(width: size, height: size)
            .brutalBox(fill: accent?.color ?? Palette.paper, radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

/// The big yellow + button.
struct AddButton: View {
    var label: String = "Add"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 62, height: 62)
                .contentShape(Rectangle())
        }
        .buttonStyle(BrutalSquarePressStyle(fill: Accent.yellow.color, shadow: Metrics.shadow, radius: Metrics.radius))
        .accessibilityLabel(label)
    }
}

/// The + look, used as a Menu label.
struct AddButtonLabel: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 28, weight: .black))
            .foregroundStyle(Palette.ink)
            .frame(width: 62, height: 62)
            .brutalBox(fill: Accent.yellow.color, radius: Metrics.radius)
            .accessibilityLabel("Add")
    }
}

// MARK: - Chips, headers, progress

/// A pill with an accent fill, thin ink outline and bold caption.
struct Chip: View {
    let text: String
    var accent: Accent = .yellow
    var symbol: String? = nil
    var selected: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
            Text(text).font(Typeface.body(12, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(selected ? accent.onColor : Palette.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(selected ? accent.color : Palette.paper))
        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
    }
}

/// A chip you can tap to filter.
struct FilterChip: View {
    let text: String
    var accent: Accent = .yellow
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Chip(text: text, accent: accent, symbol: symbol, selected: selected)
        }
        .buttonStyle(.plain)
    }
}

/// Bold section title, with an optional count on the right.
struct SectionHeader: View {
    let title: String
    var count: Int? = nil
    var accent: Accent? = nil

    init(_ title: String, count: Int? = nil, accent: Accent? = nil) {
        self.title = title
        self.count = count
        self.accent = accent
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let accent {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.color)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
                    .frame(width: 12, height: 12)
            }
            Text(title)
                .font(Typeface.heading(20))
                .foregroundStyle(Palette.ink)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(Typeface.heading(15))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Bold header for a Form section.
struct FormHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(Typeface.heading(15))
            .foregroundStyle(Palette.ink)
            .textCase(nil)
    }
}

/// An outlined progress bar with a flat accent fill.
struct BrutalProgress: View {
    let value: Double
    var accent: Accent = .yellow
    var height: CGFloat = 16

    var body: some View {
        let v = min(max(value.isFinite ? value : 0, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.paper)
                Rectangle()
                    .fill(accent.color)
                    .frame(width: geo.size.width * v)
                    .overlay(alignment: .trailing) {
                        if v > 0 && v < 1 { Rectangle().fill(Palette.ink).frame(width: Metrics.borderThin) }
                    }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Palette.ink, lineWidth: Metrics.border))
        .accessibilityElement()
        .accessibilityValue("\(Int(v * 100)) percent")
    }
}

/// "Label ........ value" on a card.
struct StatLine: View {
    let label: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(Typeface.body(15)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(bold ? Typeface.heading(17) : Typeface.body(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
    }
}

// MARK: - Text fields

/// Paper field with an ink outline.
struct BrutalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Typeface.body(16))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

extension TextFieldStyle where Self == BrutalTextFieldStyle {
    static var brutal: BrutalTextFieldStyle { BrutalTextFieldStyle() }
}

/// A one-line "add" field: type, press return. Used on Today, Tasks, Selling, Packing, Prayer.
struct QuickAddField: View {
    let prompt: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Palette.ink)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 5).fill(Accent.yellow.color))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
            TextField(prompt, text: $text)
                .font(Typeface.body(16))
                .foregroundStyle(Palette.ink)
                .submitLabel(.done)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

// MARK: - Empty state

struct BrutalEmptyState: View {
    let symbol: String
    let title: String
    var message: String = ""
    var accent: Accent = .yellow

    var body: some View {
        VStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: symbol, accent: accent, size: 64)
            Text(title)
                .font(Typeface.heading(20))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if !message.isEmpty {
                Text(message)
                    .font(Typeface.body(15))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Metrics.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Small helpers used on many screens

/// "Today", "Tomorrow", or "Fri 9 Oct".
func shortDate(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInTomorrow(d) { return "Tomorrow" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    return d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
}

func longDate(_ d: Date) -> String {
    d.formatted(date: .abbreviated, time: .omitted)
}

/// Euros, whole numbers when possible.
func euros(_ cents: Int) -> String { Money.text(cents, "EUR") }

/// A date in a Form that can also be empty: the date field with a × to clear it, or an "Add date" button.
struct OptionalDatePicker: View {
    let title: String
    @Binding var date: Date?
    var defaultDate: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        LabeledContent {
            if let current = date {
                HStack(spacing: Metrics.s) {
                    BrutalDateField(date: Binding(get: { current }, set: { date = $0 }))
                    IconButton(symbol: "xmark", size: 30, label: "Clear \(title)") { date = nil }
                        .padding(.trailing, Metrics.shadowSmall)
                }
            } else {
                Button("Add date") { date = defaultDate }
                    .buttonStyle(.brutalCompact)
                    .padding(.trailing, Metrics.shadowSmall)
            }
        } label: {
            Text(title).font(Typeface.body(16)).foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
    }
}

/// An amount typed in euros (or another currency), stored in cents.
struct MoneyField: View {
    let title: String
    @Binding var cents: Int
    var currency: String = "EUR"

    private var amount: Binding<Double> {
        Binding(get: { Money.euros(cents) }, set: { cents = Money.cents(fromEuros: $0) })
    }

    var body: some View {
        LabeledContent("\(title) (\(currencySymbol))") {
            TextField("0", value: amount, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }

    private var currencySymbol: String {
        switch currency {
        case "EUR": return "€"
        case "NZD": return "NZ$"
        default: return currency
        }
    }
}

/// A Form row with the card look at the top of a detail screen.
struct FormHeroRow<Content: View>: View {
    var fill: Color = Palette.paper
    @ViewBuilder var content: Content

    var body: some View {
        BrutalCard(fill: fill) { content }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: Metrics.shadow))
    }
}

/// Delete button with a confirmation, for detail screens. Dismisses first, deletes after,
/// so the screen never reads a deleted record.
struct DeleteRecordButton<T: Syncable>: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let item: T
    var extra: (() -> Void)? = nil
    /// An icon button (for toolbars) instead of the full-width danger button.
    var compact: Bool = false
    @State private var confirming = false

    var body: some View {
        Group {
            if compact {
                IconButton(symbol: "trash", accent: .pink, size: 36, label: "Delete") { confirming = true }
            } else {
                Button { confirming = true } label: {
                    Label("Delete", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(BrutalButtonStyle(kind: .danger))
                .padding(.trailing, Metrics.shadow)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }
        }
        .brutalDialog("Delete \(item.displayTitle)?", isPresented: $confirming, confirm: "Delete") {
            let doomed = item
            let context = ctx
            let more = extra
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                more?()
                Store.delete(doomed, in: context)
            }
        }
    }
}

/// Phone and WhatsApp links from a typed number.
enum PhoneLinks {
    static func call(_ phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:" + digits)
    }

    /// WhatsApp wants the number without + or leading zero; Dutch 06 numbers become 316.
    static func whatsApp(_ phone: String) -> URL? {
        var digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        if digits.hasPrefix("00") { digits.removeFirst(2) }
        else if digits.hasPrefix("0") { digits = "31" + digits.dropFirst() }
        return URL(string: "https://wa.me/\(digits)")
    }

    static func email(_ address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : URL(string: "mailto:\(trimmed)")
    }
}

/// A row in a brutal list that opens a screen without the grey chevron and highlight.
struct CardLink<Destination: View, Label: View>: View {
    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> Label

    var body: some View {
        ZStack {
            NavigationLink(destination: destination) { EmptyView() }
                .opacity(0)
            label()
        }
    }
}
