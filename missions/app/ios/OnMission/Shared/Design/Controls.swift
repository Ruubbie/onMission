import SwiftUI
import SwiftData

// Form controls for the detail pages, on the paper sheet: rows divided by fine ink rules, labels in ink,
// values in bold ink. The system pop-ups (menus, the calendar) still open from them.

// MARK: - Blocks and rows

/// A titled group of form rows, like a Form section.
struct FormBlock<Content: View>: View {
    let title: String
    var footer: String = ""
    @ViewBuilder let content: Content

    init(_ title: String, footer: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                SectionHeader(title).padding(.top, 22).padding(.bottom, 2)
            }
            content
            if !footer.isEmpty {
                Text(footer)
                    .type(.small)
                    .foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }
}

/// One form row with a rule under it.
struct FieldRow<Content: View>: View {
    var rule = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .overlay(alignment: .bottom) {
                if rule { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
            }
    }
}

/// A text field as a row.
struct TextRow: View {
    let placeholder: String
    @Binding var text: String
    var vertical = false
    var lines: ClosedRange<Int> = 1...8
    var keyboard: UIKeyboardType = .default
    var plain = false

    init(_ placeholder: String, text: Binding<String>, vertical: Bool = false, lines: ClosedRange<Int> = 1...8,
         keyboard: UIKeyboardType = .default, plain: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.vertical = vertical
        self.lines = lines
        self.keyboard = keyboard
        self.plain = plain
    }

    var body: some View {
        FieldRow {
            Group {
                if vertical {
                    TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(Palette.inkFaint), axis: .vertical)
                        .lineLimit(lines)
                } else {
                    TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(Palette.inkFaint))
                }
            }
            .type(.bodyBold)
            .foregroundStyle(Palette.ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(plain ? .never : .sentences)
            .autocorrectionDisabled(plain)
        }
    }
}

/// Label on the left, anything on the right.
struct LabeledRow<Trailing: View>: View {
    let label: String
    var rule = true
    @ViewBuilder let trailing: Trailing

    init(_ label: String, rule: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.rule = rule
        self.trailing = trailing()
    }

    var body: some View {
        FieldRow(rule: rule) {
            Text(label).type(.bodyBold).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// "Label ........ value" (read-only).
struct ValueRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledRow(label) {
            Text(value).type(.body).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.trailing)
        }
    }
}

/// A tappable row with an icon (Attach a file, Record a gift…).
struct ActionRow: View {
    let title: String
    var icon: Icon = .chev
    var role: ButtonRole? = nil
    let action: () -> Void
    @State private var play = 0

    var body: some View {
        Button(role: role) {
            play += 1
            action()
        } label: {
            FieldRow {
                AnimatedIcon(icon, size: 20, trigger: play).foregroundStyle(role == .destructive ? Palette.error : Palette.ink)
                Text(title).type(.bodyBold).foregroundStyle(role == .destructive ? Palette.error : Palette.ink)
                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle

/// A sage track with a paper knob when on, an ink outline when off. Set once on the root, so every Toggle uses it.
struct PaperToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Metrics.m) {
                configuration.label
                    .type(.bodyBold)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? Palette.sageDeep : Color.clear)
                    Capsule().strokeBorder(configuration.isOn ? Palette.sageDeep : Palette.chipRule, lineWidth: Metrics.outline)
                    Circle()
                        .fill(configuration.isOn ? Palette.paper : Palette.ink.opacity(0.35))
                        .frame(width: 22, height: 22)
                        .padding(.horizontal, 4)
                }
                .frame(width: 50, height: 30)
                .animation(.curve(0.3, 1.4, 0.5, 1, 0.3).rm, value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

extension ToggleStyle where Self == PaperToggleStyle {
    static var paper: PaperToggleStyle { PaperToggleStyle() }
}

/// A toggle as a row.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        FieldRow { Toggle(title, isOn: $isOn).toggleStyle(.paper) }
    }
}

// MARK: - Select

/// Label on the left, the current value in bold ink on the right; tapping opens the system menu.
struct SelectRow<V: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: V
    @ViewBuilder var content: Content

    init(_ title: String, selection: Binding<V>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        LabeledRow(title) {
            Picker(title, selection: $selection) { content }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Palette.ink)
        }
    }
}

// MARK: - Dates

/// "Fri 9 Oct" with a calendar icon, in an outlined capsule. Tapping opens the system calendar.
struct DateField: View {
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        HStack(spacing: 8) {
            Text(text).type(TypeStyle(size: 15.5, wght: 650, relativeTo: .body)).foregroundStyle(Palette.ink).lineLimit(1)
            AnimatedIcon(.calendar, size: 17).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .overlay(Capsule().strokeBorder(Palette.chipRule, lineWidth: Metrics.outline))
        // The real (invisible) picker on top takes the tap and opens the calendar.
        .overlay {
            DatePicker("", selection: $date, displayedComponents: components)
                .labelsHidden()
                .opacity(0.02)
        }
    }

    private var text: String {
        components.contains(.hourAndMinute)
            ? "\(shortDate(date)), \(date.formatted(date: .omitted, time: .shortened))"
            : shortDate(date)
    }
}

struct DateRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        LabeledRow(title) { DateField(date: $date, components: components) }
    }
}

/// A date that can also be empty: the date field with a × to clear it, or "Add date".
struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?
    var defaultDate: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        LabeledRow(title) {
            if let current = date {
                HStack(spacing: 6) {
                    DateField(date: Binding(get: { current }, set: { date = $0 }))
                    Button { date = nil } label: {
                        AnimatedIcon(.x, size: 14).foregroundStyle(Palette.inkSoft).frame(width: 32, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title)")
                }
            } else {
                Button("Add date") { date = defaultDate }
                    .buttonStyle(.outlinedSmall)
            }
        }
    }
}

/// One-tap dates under a date row: Today, Tomorrow, In 3 days, Next week.
struct QuickDates: View {
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
                    let target = Calendar.current.date(byAdding: .day, value: option.days, to: Calendar.current.startOfDay(for: .now))
                    let on = isSame(date, target)
                    Button {
                        withAnimation(Motion.indicator.rm) { date = target }
                    } label: {
                        Text(option.title)
                            .type(TypeStyle(size: 14, wght: 650, relativeTo: .subheadline))
                            .foregroundStyle(on ? Palette.paper : Palette.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background {
                                if on { Capsule().fill(Palette.ink) } else { Capsule().strokeBorder(Palette.chipRule, lineWidth: Metrics.outline) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func isSame(_ a: Date?, _ b: Date?) -> Bool {
        guard let a, let b else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
    }
}

// MARK: - Numbers

/// An amount typed in euros (or another currency), stored in cents.
struct MoneyRow: View {
    let title: String
    @Binding var cents: Int
    var currency: String = "EUR"

    private var amount: Binding<Double> {
        Binding(get: { Money.euros(cents) }, set: { cents = Money.cents(fromEuros: $0) })
    }

    var body: some View {
        LabeledRow("\(title) (\(symbol))") {
            TextField("0", value: amount, format: .number)
                .type(TypeStyle(size: 15.5, wght: 650, relativeTo: .body))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 140)
        }
    }

    private var symbol: String {
        switch currency {
        case "EUR": "€"
        case "NZD": "NZ$"
        default: currency
        }
    }
}

struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        LabeledRow(title) {
            HStack(spacing: 6) {
                step(.minus, enabled: value > range.lowerBound) { value -= 1 }
                Text("\(value)")
                    .type(TypeStyle(size: 15.5, wght: 650, relativeTo: .body))
                    .monospacedDigit()
                    .frame(minWidth: 28)
                step(.plus, enabled: value < range.upperBound) { value += 1 }
            }
        }
    }

    private func step(_ icon: Icon, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AnimatedIcon(icon, size: 16)
                .foregroundStyle(enabled ? Palette.ink : Palette.inkFaint)
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(Palette.chipRule, lineWidth: Metrics.outline))
                .contentShape(Circle())
        }
        .buttonStyle(.press)
        .disabled(!enabled)
    }
}

/// The page's own title, edited in place (big and tight, like the letter title on the web).
struct TitleField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(Palette.inkFaint), axis: .vertical)
            .type(TypeStyle(size: 26, wght: 820, tracking: -0.04, relativeTo: .title))
            .foregroundStyle(Palette.ink)
            .lineLimit(1...4)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
    }
}

// MARK: - Confirm and delete

extension View {
    /// Asks before something that can't be undone.
    func confirm(_ title: String, isPresented: Binding<Bool>, message: String = "", button: String = "Delete",
                 action: @escaping () -> Void) -> some View {
        alert(title, isPresented: isPresented) {
            Button(button, role: .destructive, action: action)
            Button("Cancel", role: .cancel) {}
        } message: {
            if !message.isEmpty { Text(message) }
        }
    }

    /// A message with only OK.
    func notice(_ title: String, message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

/// Delete with a confirmation on detail pages. Goes back first and deletes after, so the page
/// never reads a deleted record.
struct DeleteButton<T: Syncable>: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    let item: T
    var extra: (() -> Void)? = nil
    @State private var confirming = false

    var body: some View {
        ActionRow(title: "Delete", icon: .trash, role: .destructive) { confirming = true }
            .padding(.top, 18)
            .confirm("Delete \(item.displayTitle)?", isPresented: $confirming) {
                let doomed = item
                let context = ctx
                let more = extra
                router.back()
                Motion.after(0.7, always: true) {
                    more?()
                    Store.delete(doomed, in: context)
                }
            }
    }
}
