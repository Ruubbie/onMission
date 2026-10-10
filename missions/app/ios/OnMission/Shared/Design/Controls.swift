import SwiftUI

// Our own versions of the controls that would otherwise look like iOS (design-system.md, section 6).
// The system's own pop-ups (menu list, calendar) still open from them.

// MARK: - Toggle

/// Pill track with a paper knob. Set once on the root, so every Toggle uses it.
struct BrutalToggleStyle: ToggleStyle {
    var on: Color = Palette.ok

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn = !configuration.isOn
        } label: {
            HStack(spacing: Metrics.m) {
                configuration.label
                    .font(Typeface.body(16))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? on : Palette.paper)
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: 22, height: 22)
                        .offset(x: 2, y: 2)
                        .overlay {
                            Circle().fill(Palette.paper)
                                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: Metrics.border))
                        }
                        .padding(.horizontal, 3)
                }
                .frame(width: 52, height: 30)
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: Metrics.border))
                .animation(.easeOut(duration: 0.12), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == BrutalToggleStyle {
    static var brutal: BrutalToggleStyle { BrutalToggleStyle() }
}

// MARK: - Segmented control

struct BrutalSegmented<V: Hashable>: View {
    let options: [(value: V, label: String)]
    @Binding var selection: V
    var accent: Accent = .yellow

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                let selected = option.value == selection
                if i > 0 { Rectangle().fill(Palette.ink).frame(width: Metrics.border) }
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(selected ? Typeface.heading(14) : Typeface.body(14))
                        .foregroundStyle(selected ? accent.onColor : Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? accent.color : Palette.paper)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous))
        .brutalBox(fill: Palette.paper, radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

// MARK: - Select (a Picker in a box)

/// Label on the left, the current value in a paper box on the right. Tapping opens the system menu.
/// Same signature as `Picker(_:selection:content:)`.
struct BrutalSelect<V: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: V
    @ViewBuilder var content: Content

    init(_ title: String, selection: Binding<V>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        LabeledContent {
            Picker(title, selection: $selection) { content }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Palette.ink)
                .font(Typeface.body(16, weight: .semibold))
                .padding(.horizontal, 2)
                .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
                .padding(.trailing, Metrics.shadowSmall)
                .padding(.vertical, 2)
        } label: {
            Text(title).font(Typeface.body(16)).foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Date field

/// "Fri 9 Oct" in a select-style box with a calendar icon. Tapping opens the system calendar.
struct BrutalDateField: View {
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(Typeface.body(16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
        // The real (invisible) picker on top takes the tap and opens the calendar.
        .overlay {
            DatePicker("", selection: $date, displayedComponents: components)
                .labelsHidden()
                .opacity(0.02)
        }
        .padding(.trailing, Metrics.shadowSmall)
    }

    private var text: String {
        components.contains(.hourAndMinute)
            ? "\(shortDate(date)), \(date.formatted(date: .omitted, time: .shortened))"
            : shortDate(date)
    }
}

/// A form row: label left, date field right.
struct BrutalDateRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        LabeledContent {
            BrutalDateField(date: $date, components: components)
        } label: {
            Text(title).font(Typeface.body(16)).foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - Stepper

struct BrutalStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(Typeface.body(16)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            step("minus", enabled: value > range.lowerBound) { value -= 1 }
            Text("\(value)")
                .font(Typeface.heading(17))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(minWidth: 28)
            step("plus", enabled: value < range.upperBound) { value += 1 }
                .padding(.trailing, Metrics.shadowSmall)
        }
    }

    private func step(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(enabled ? Palette.ink : Palette.muted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(BrutalSquarePressStyle(shadow: enabled ? Metrics.shadowSmall : 0))
        .disabled(!enabled)
    }
}

// MARK: - Search field

struct BrutalSearchField: View {
    @Binding var text: String
    var prompt: String = "Search"

    var body: some View {
        HStack(spacing: Metrics.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.ink)
            TextField(prompt, text: $text)
                .font(Typeface.body(16))
                .foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Palette.paper))
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

extension View {
    /// A search field pinned at the top of the screen, under the title. Replaces `.searchable`.
    func brutalSearch(text: Binding<String>, prompt: String = "Search") -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            BrutalSearchField(text: text, prompt: prompt)
                .padding(.leading, Metrics.l)
                .padding(.trailing, Metrics.l + Metrics.shadowSmall)
                .padding(.top, 4)
                .padding(.bottom, Metrics.m)
                .background(Palette.background)
        }
    }
}

// MARK: - Spinner

/// A yellow square that turns in hard steps every 150 ms (a square turned a full 90° would look still).
struct BrutalSpinner: View {
    var size: CGFloat = 20

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.15) % 4
            RoundedRectangle(cornerRadius: 3)
                .fill(Accent.yellow.color)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ink, lineWidth: Metrics.border))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(Double(step) * 22.5))
        }
        .accessibilityLabel("Loading")
    }
}

// MARK: - Dialog

/// A paper card on a dark scrim. Replaces alerts and the Delete action sheet.
struct BrutalDialog: View {
    let title: String
    var message: String = ""
    var confirm: String? = nil
    var cancel: String = "Cancel"
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(alignment: .leading, spacing: Metrics.m) {
                Text(title)
                    .font(Typeface.heading(20))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.isEmpty {
                    Text(message)
                        .font(Typeface.body(15))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: Metrics.m) {
                    if let confirm {
                        Button {
                            onClose()
                            onConfirm()
                        } label: { Text(confirm).frame(maxWidth: .infinity) }
                        .buttonStyle(BrutalButtonStyle(kind: .danger))
                    }
                    Button(action: onClose) { Text(cancel).frame(maxWidth: .infinity) }
                        .buttonStyle(.brutalSecondary)
                }
                .padding(.top, 4)
                .padding(.trailing, Metrics.shadow)
            }
            .padding(Metrics.xl)
            .brutalBox()
            .padding(.horizontal, 32)
        }
    }
}

extension View {
    /// Shows a `BrutalDialog` while `isPresented` is true. Without `confirm` it only has an OK button.
    func brutalDialog(_ title: String, isPresented: Binding<Bool>, message: String = "",
                      confirm: String? = nil, action: @escaping () -> Void = {}) -> some View {
        modifier(BrutalDialogModifier(title: title, message: message, confirm: confirm,
                                      isPresented: isPresented, action: action))
    }
}

private struct BrutalDialogModifier: ViewModifier {
    let title: String
    let message: String
    let confirm: String?
    @Binding var isPresented: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            BrutalDialog(title: title, message: message, confirm: confirm,
                         cancel: confirm == nil ? "OK" : "Cancel",
                         onConfirm: action, onClose: { isPresented = false })
                .presentationBackground(.clear)
        }
    }
}

// MARK: - Toolbar buttons

extension View {
    /// Cancel and Save in a sheet's header, as compact buttons instead of blue text.
    func brutalSheetToolbar(cancel: @escaping () -> Void, save: String? = nil, saveDisabled: Bool = false,
                            onSave: @escaping () -> Void = {}) -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel).buttonStyle(.brutalCompact)
            }
            if let save {
                ToolbarItem(placement: .confirmationAction) {
                    Button(save, action: onSave)
                        .buttonStyle(BrutalButtonStyle(kind: .primary, compact: true))
                        .disabled(saveDisabled)
                        .opacity(saveDisabled ? 0.5 : 1)
                }
            }
        }
        .toolbarBackground(Palette.background, for: .navigationBar)
        .presentationDragIndicator(.visible)
    }
}
