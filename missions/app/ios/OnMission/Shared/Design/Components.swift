import SwiftUI
import SwiftData

// The building blocks of the Mocha & Ollie look: a mocha gradient page, soft mocha cards
// without outlines, pill buttons in Ollie's sage, and one cream focal card per screen.
// (The "brutal" names stay from the first design so every screen keeps compiling.)

// MARK: - The basic box: a filled shape

extension View {
    /// A filled shape behind the content. `shadow` and `border` are kept for old call sites and ignored.
    func brutalBox<S: Shape>(shape: S, fill: Color = Palette.paper, shadow: CGFloat = Metrics.shadow,
                             border: CGFloat = Metrics.border) -> some View {
        self.background { shape.fill(fill) }
    }

    /// The same, with a rounded rectangle.
    func brutalBox(fill: Color = Palette.paper, radius: CGFloat = Metrics.radius, shadow: CGFloat = Metrics.shadow,
                   border: CGFloat = Metrics.border) -> some View {
        brutalBox(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), fill: fill, shadow: shadow, border: border)
    }

    /// The dashed stitch just inside a card's edge (focal cards and the thanks card).
    func stitched(_ color: Color = Palette.stitch, radius: CGFloat = Metrics.radius) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: max(radius - 6, 4), style: .continuous)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(6)
                .allowsHitTesting(false)
        }
    }

    /// The mocha gradient behind a screen (also behind Lists and Forms).
    func brutalBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Palette.gradient.ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// A Form in the app's style: mocha page, mocha rows, sage tint.
    func brutalForm() -> some View {
        self
            .brutalBackground()
            .tint(Accent.yellow.color)
            .listRowBackground(Palette.paper)
            .listRowSeparatorTint(Palette.hairline)
            .listSectionSpacing(Metrics.xl)
            .foregroundStyle(Palette.ink)
    }

    /// A plain List whose rows are cards.
    func brutalList() -> some View {
        self
            .listStyle(.plain)
            .brutalBackground()
            .environment(\.defaultMinListRowHeight, 1)
    }

    /// A row inside `brutalList()`: no separator, no grey background.
    func brutalRow(top: CGFloat = 6, bottom: CGFloat = 8) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: Metrics.l, bottom: bottom, trailing: Metrics.l))
    }

    /// A + in the navigation bar that makes a new record of this screen's kind and opens it.
    /// (The floating sage + next to the tab bar is Capture, the same on every screen.)
    func addButton(_ action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                IconButton(symbol: "plus", size: 36, label: "New", action: action)
            }
        }
    }

    /// The navigation-bar + that opens a menu of things to add.
    func addMenu<MenuContent: View>(@ViewBuilder _ content: @escaping () -> MenuContent) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu(content: content) { IconTile(symbol: "plus", size: 36) }
                    .accessibilityLabel("New")
            }
        }
    }
}

// MARK: - Cards

/// A soft mocha card.
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
        .brutalBox(fill: fill)
    }
}

/// The one cream card on a screen, with its stitch. Text inside uses `Cream.ink` / `Cream.sub`.
struct FocalCard<Content: View>: View {
    var padding: CGFloat = Metrics.l
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Cream.ink)
        .brutalBox(fill: Cream.fill)
        .stitched(Cream.stitch)
    }
}

/// Small uppercase label ("START WITH THANKS").
struct Cap: View {
    let text: String
    var color: Color = Palette.muted
    init(_ text: String, color: Color = Palette.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(Typeface.cap)
            .kerning(0.7)
            .foregroundStyle(color)
    }
}

/// A soft tile with an accent dot, a title and one live line. Used on More.
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
        VStack(alignment: .leading, spacing: 2) {
            Circle().fill(accent.color).frame(width: 10, height: 10).padding(.bottom, 6)
            Text(title)
                .font(Typeface.body(14, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text([count, subtitle].filter { !$0.isEmpty }.joined(separator: " "))
                .font(Typeface.body(12, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
        }
        .padding(Metrics.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(radius: 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// An icon in a small accent circle.
struct AccentSquareIcon: View {
    let symbol: String
    var accent: Accent = .yellow
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(accent.onColor)
            .frame(width: size, height: size)
            .background(Circle().fill(accent.color))
    }
}

/// Initials in a soft circle (Support list).
struct Avatar: View {
    let name: String
    var size: CGFloat = 30
    var body: some View {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map { String($0) }.joined().uppercased()
        Text(letters.isEmpty ? "?" : letters)
            .font(Typeface.body(11, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.chip))
    }
}

/// A small tinted status pill (Partner, Thinking, Answered).
struct Pill: View {
    let text: String
    var accent: Accent = .yellow
    var body: some View {
        Text(text)
            .font(Typeface.body(10.5, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(accent.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent.color.opacity(0.22)))
    }
}

// MARK: - Buttons

/// A pill button. Primary is sage, secondary a soft chip, danger coral.
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
        case .secondary: return Palette.chip
        case .danger: return Palette.danger
        }
    }

    private var foreground: Color { kind == .secondary && fill == nil ? Palette.ink : Palette.onAccent }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.body(compact ? 13 : 15, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 6 : 10)
            .background(Capsule().fill(background))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrutalButtonStyle {
    static var brutal: BrutalButtonStyle { BrutalButtonStyle(kind: .primary) }
    static var brutalSecondary: BrutalButtonStyle { BrutalButtonStyle(kind: .secondary) }
    static var brutalCompact: BrutalButtonStyle { BrutalButtonStyle(kind: .secondary, compact: true) }
}

/// Soft press for round icon and add buttons.
struct BrutalSquarePressStyle: ButtonStyle {
    var fill: Color = Palette.chip
    var shadow: CGFloat = Metrics.shadowSmall
    var radius: CGFloat = 999

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// A round icon button.
struct IconButton: View {
    let symbol: String
    var accent: Accent? = nil
    var size: CGFloat = 40
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(accent?.onColor ?? Palette.ink)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(BrutalSquarePressStyle(fill: accent?.color ?? Palette.chip))
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
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(accent?.onColor ?? Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(accent?.color ?? Palette.chip))
    }
}

/// The round sage + button.
struct AddButton: View {
    var label: String = "Add"
    let action: () -> Void

    var body: some View {
        Button(action: action) { AddButtonLabel(label: label) }
            .buttonStyle(.plain)
    }
}

/// The + look, also used as a Menu label.
struct AddButtonLabel: View {
    var label: String = "Add"
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 24, weight: .medium))
            .foregroundStyle(Palette.onAccent)
            .frame(width: 52, height: 52)
            .background(Circle().fill(Accent.yellow.color))
            .shadow(color: .black.opacity(0.35), radius: 9, y: 6)
            .contentShape(Circle())
            .accessibilityLabel(label)
    }
}

// MARK: - Chips, headers, progress

/// A pill: soft chip fill, or the accent tint when `selected`.
struct Chip: View {
    let text: String
    var accent: Accent = .yellow
    var symbol: String? = nil
    var selected: Bool = true
    /// Full accent fill with dark text (selected filters, segments).
    var strong: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
            Text(text).font(Typeface.body(12, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(strong ? accent.onColor : (selected ? Palette.ink : Palette.muted))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(strong ? accent.color : (selected ? accent.color.opacity(0.26) : Palette.chip)))
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
            Chip(text: text, accent: .yellow, symbol: symbol, selected: false, strong: selected)
        }
        .buttonStyle(.plain)
    }
}

/// Section title, with an optional count on the right.
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
            Cap(title)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(Typeface.body(12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Header for a Form section.
struct FormHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Cap(title).textCase(nil)
    }
}

/// A soft rounded progress bar. `goal` adds a thin green marker (0...1).
struct BrutalProgress: View {
    let value: Double
    var accent: Accent = .yellow
    var height: CGFloat = 10
    var goal: Double? = nil

    var body: some View {
        let v = min(max(value.isFinite ? value : 0, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.chip)
                Capsule().fill(accent.color).frame(width: max(v > 0 ? height : 0, geo.size.width * v))
                if let goal {
                    Rectangle().fill(Accent.green.color)
                        .frame(width: 2, height: height + 8)
                        .offset(x: geo.size.width * min(max(goal, 0), 1) - 1)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + (goal == nil ? 0 : 8))
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
            Text(label).font(Typeface.body(14)).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(Typeface.body(bold ? 16 : 14, weight: bold ? .bold : .semibold))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
    }
}

// MARK: - Text fields

/// Soft field on a slightly lighter surface.
struct BrutalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Typeface.body(15))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .brutalBox(radius: Metrics.radiusSmall)
    }
}

extension TextFieldStyle where Self == BrutalTextFieldStyle {
    static var brutal: BrutalTextFieldStyle { BrutalTextFieldStyle() }
}

/// A one-line "add" field: type, press return. Used on Tasks, Selling, Packing, Prayer.
struct QuickAddField: View {
    let prompt: String
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Accent.yellow.color))
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Palette.muted))
                .font(Typeface.body(15))
                .foregroundStyle(Palette.ink)
                .submitLabel(.done)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .brutalBox(radius: Metrics.radiusSmall)
    }
}

// MARK: - Empty state

struct BrutalEmptyState: View {
    let symbol: String
    let title: String
    var message: String = ""
    var accent: Accent = .yellow
    /// Ollie instead of the icon.
    var ollie: OlliePose? = nil

    var body: some View {
        VStack(spacing: Metrics.m) {
            if let ollie {
                Ollie(pose: ollie, height: 90)
            } else {
                AccentSquareIcon(symbol: symbol, accent: accent, size: 56)
            }
            Text(title)
                .font(Typeface.heading(17))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if !message.isEmpty {
                Text(message)
                    .font(Typeface.body(14))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Metrics.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Small helpers used on many screens

/// "Today", "Tomorrow", or "Fri 9 Oct". `midSentence` gives "today" for "Was due today".
func shortDate(_ d: Date, midSentence: Bool = false) -> String {
    let cal = Calendar.current
    let relative: String?
    if cal.isDateInToday(d) { relative = "Today" }
    else if cal.isDateInTomorrow(d) { relative = "Tomorrow" }
    else if cal.isDateInYesterday(d) { relative = "Yesterday" }
    else { relative = nil }
    if let relative { return midSentence ? relative.lowercased() : relative }
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
            Text(title).font(Typeface.body(15)).foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
    }
}

/// One-tap dates under a date field: Today, Tomorrow, In 3 days, Next week.
struct QuickDateChips: View {
    struct Option: Identifiable {
        let title: String
        let days: Int
        var id: Int { days }
    }

    @Binding var date: Date?
    var options: [Option] = [Option(title: "Today", days: 0), Option(title: "Tomorrow", days: 1),
                             Option(title: "In 3 days", days: 3), Option(title: "Next week", days: 7)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    let target = Calendar.current.date(byAdding: .day, value: option.days,
                                                       to: Calendar.current.startOfDay(for: .now))
                    FilterChip(text: option.title, selected: isSame(date, target)) {
                        withAnimation(.easeOut(duration: 0.15)) { date = target }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func isSame(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
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
