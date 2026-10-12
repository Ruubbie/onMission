import SwiftUI
import SwiftData

// The building blocks of Tomato Flood (handoff §3): a poster on tomato that never scrolls, a cream sheet
// that holds the rest, rows with rules, rings that tick, capsule buttons, tiles, segments, pills and a toast.

// MARK: - Chrome

/// Where the bars sit, measured once by the root.
struct Chrome {
    var top: CGFloat = 59
    var bottomSafe: CGFloat = 34
    var width: CGFloat = 390
    var height: CGFloat = 844
    /// The tab bar's full height, including the home-indicator area (0 while the keyboard is up).
    var bar: CGFloat = 89

    /// Posters are designed 390 wide; they scale with the phone and shrink a little on short phones.
    func posterScale(_ dts: DynamicTypeSize) -> CGFloat {
        var k = min(width / Metrics.designWidth, 1.12)
        if height < 760 { k *= 0.84 }
        if dts.isAccessibilitySize { k *= 0.8 }
        return k
    }
}

extension EnvironmentValues {
    @Entry var chrome = Chrome()
}

// MARK: - Screen: poster + sheet

/// The layers every tab and page share: room for the top bar, a poster that never scrolls,
/// a cream sheet (or more tomato), and room for the tab bar.
struct Screen<Poster: View, Sheet: View>: View {
    /// The poster's height on the 390 × 844 design (sheet top − 104).
    let posterHeight: CGFloat
    var background: Color = Palette.tomato
    var sheetTop: CGFloat = Metrics.sheetTop
    let hasSheet: Bool
    let poster: Poster
    let sheet: Sheet

    @Environment(\.chrome) private var chrome
    @Environment(\.dynamicTypeSize) private var dts

    init(posterHeight: CGFloat, background: Color = Palette.tomato, sheetTop: CGFloat = Metrics.sheetTop,
         @ViewBuilder poster: () -> Poster, @ViewBuilder sheet: () -> Sheet) {
        self.posterHeight = posterHeight
        self.background = background
        self.sheetTop = sheetTop
        self.hasSheet = true
        self.poster = poster()
        self.sheet = sheet()
    }

    var body: some View {
        let k = chrome.posterScale(dts)
        VStack(spacing: 0) {
            Color.clear.frame(height: chrome.top + Metrics.topBar)
            PosterCanvas(height: posterHeight, scale: k) { poster }
                .accessibilityElement(children: .combine)
            if hasSheet {
                SheetSurface(top: sheetTop) { sheet }
                    .riseSheet()
            } else {
                Spacer(minLength: 0)
            }
            Color.clear.frame(height: chrome.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
        .foregroundStyle(Palette.cream)
    }
}

extension Screen where Sheet == EmptyView {
    /// A screen that is all poster (Prayer, All done).
    init(posterHeight: CGFloat, background: Color = Palette.tomato, @ViewBuilder poster: () -> Poster) {
        self.posterHeight = posterHeight
        self.background = background
        self.sheetTop = Metrics.sheetTop
        self.hasSheet = false
        self.poster = poster()
        self.sheet = EmptyView()
    }
}

/// A 390-wide design canvas, scaled to the phone. Place children with `.at(x, y)` in prototype points.
struct PosterCanvas<Content: View>: View {
    let height: CGFloat
    let scale: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
        }
        .frame(width: Metrics.designWidth, height: height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: Metrics.designWidth * scale, height: height * scale, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Places a poster element at the prototype's CSS `left` / `top` (top bar bottom is at 104, plus 20pt of air).
    func at(_ left: CGFloat, _ top: CGFloat) -> some View {
        offset(x: left, y: top - 84)
    }
}

/// The cream sheet: top corners 30, 22/20 padding, everything inside on ink.
struct SheetSurface<Content: View>: View {
    var top: CGFloat = Metrics.sheetTop
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.top, top)
        .padding(.horizontal, Metrics.sheetSide)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: Metrics.sheetRadius, topTrailingRadius: Metrics.sheetRadius, style: .continuous)
                .fill(Palette.cream)
                .ignoresSafeArea(edges: .bottom)
        )
        .foregroundStyle(Palette.ink)
    }
}

/// A scroll view inside a sheet that runs edge to edge with the sheet's padding.
struct SheetScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Metrics.sheetSide)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, -Metrics.sheetSide)
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Poster type

/// Text with a CSS line-height below the font's own: lines stack with the right gap and the block shifts
/// to where the prototype's line box puts the glyphs.
struct Lines: View {
    let text: String
    let style: TypeStyle
    var lineHeight: CGFloat = 0.88
    var alignment: HorizontalAlignment = .leading
    var minScale: CGFloat = 0.5

    init(_ text: String, _ style: TypeStyle, lineHeight: CGFloat = 0.88, alignment: HorizontalAlignment = .leading,
         minScale: CGFloat = 0.5) {
        self.text = text
        self.style = style
        self.lineHeight = lineHeight
        self.alignment = alignment
        self.minScale = minScale
    }

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: alignment, spacing: FontMetrics.lineGap(style.family, size: style.size, lineHeight: lineHeight)) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .type(style)
                    .lineLimit(1)
                    .minimumScaleFactor(minScale)
                    .fixedSize(horizontal: minScale >= 1, vertical: false)
            }
        }
        .offset(y: FontMetrics.shift(style.family, size: style.size, lineHeight: lineHeight))
    }
}

/// A handwritten aside, often tilted.
struct Hand: View {
    let text: String
    var size: CGFloat = 33
    var tilt: Double = 0

    init(_ text: String, size: CGFloat = 33, tilt: Double = 0) {
        self.text = text
        self.size = size
        self.tilt = tilt
    }

    var body: some View {
        Lines(text, .hand(size), lineHeight: 0.95, minScale: 0.6)
            .rotationEffect(.degrees(tilt), anchor: .leading)
    }
}

/// The capitals line under a big number.
struct CapLine: View {
    let text: String
    var size: CGFloat = 21

    init(_ text: String, size: CGFloat = 21) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Lines(text, TypeStyle.cap.with(size: size), lineHeight: 1.05, minScale: 0.6)
    }
}

// MARK: - Sections and rows

/// "NEXT UP" in small tracked capitals, with an optional count on the right.
struct SectionHeader: View {
    let title: String
    var count: String? = nil
    var color: Color = Palette.tomatoInk

    init(_ title: String, count: String? = nil, color: Color = Palette.tomatoInk) {
        self.title = title
        self.count = count
        self.color = color
    }

    init(_ title: String, count: Int?, color: Color = Palette.tomatoInk) {
        self.init(title, count: count.map { "\($0)" }, color: color)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).type(.section).foregroundStyle(color)
            Spacer(minLength: 8)
            if let count {
                Text(count).type(.count).foregroundStyle(Palette.inkFaint)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Title and subtitle of a row.
struct RowText: View {
    let title: String
    var subtitle: String = ""
    var late = false
    var struck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .type(.rowTitle)
                .strikethrough(struck, color: Palette.ink)
                .opacity(struck ? 0.5 : 1)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .type(late ? TypeStyle.rowSub.withWeight(700) : .rowSub)
                    .foregroundStyle(late ? Palette.tomatoInk : Palette.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension TypeStyle {
    func withWeight(_ w: CGFloat) -> TypeStyle { var s = self; s.wght = w; return s }
}

/// A sheet row: 12pt above and below, a 1.5pt tomato rule under it unless it's the last.
struct Row<Content: View>: View {
    var rule = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            content
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if rule { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        }
    }
}

/// The right-aligned "when" of a row.
struct WhenText: View {
    let text: String
    var late = false

    var body: some View {
        Text(text)
            .type(.when)
            .foregroundStyle(late ? Palette.tomatoInk : Palette.ink)
            .lineLimit(1)
            .frame(minWidth: 44, alignment: .trailing)
    }
}

/// "All 48 people →": tomato, with the arrow that pulls back when tapped.
struct MoreLink: View {
    let title: String
    let action: () -> Void
    @State private var play = 0

    var body: some View {
        Button {
            play += 1
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title).type(.button)
                AnimatedIcon(.arrow, size: 18, trigger: play)
            }
            .foregroundStyle(Palette.tomatoInk)
            .padding(.top, 16)
            .frame(minHeight: 44, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
    }
}

/// "+2 more to pack": quiet, not a button.
struct MoreNote: View {
    let text: String

    var body: some View {
        Text(text).type(.small).foregroundStyle(Palette.inkFaint).padding(.top, 12)
    }
}

/// A row saying there's nothing here.
struct EmptyRow: View {
    let title: String
    var message: String = ""

    var body: some View {
        Row(rule: false) { RowText(title: title, subtitle: message) }
    }
}

// MARK: - Ring

/// The 28pt tick ring: fills (0.22s), its check draws (0.32s after 0.12s).
struct Ring: View {
    let ticked: Bool
    var size: CGFloat = 28

    var body: some View {
        let line = size >= 28 ? 2.2 : 2.0
        ZStack {
            Circle().fill(ticked ? Palette.tomato : Color.clear)
                .animation(.easeOut(duration: 0.22), value: ticked)
            Circle().strokeBorder(Palette.tomato, lineWidth: line)
            SVGShape(d: "M4 12 9 17L20 6")
                .trim(from: 0, to: ticked ? 1 : 0)
                .stroke(Palette.cream, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 24)
                .scaleEffect(size * 0.57 / 24)
                .frame(width: size * 0.57, height: size * 0.57)
                .animation(.curve(0.6, 0, 0.3, 1, 0.32).delay(0.12), value: ticked)
        }
        .frame(width: size, height: size)
    }
}

/// A ring you tap to tick; 44pt to tap without growing the row.
struct RingButton: View {
    let ticked: Bool
    var size: CGFloat = 28
    var label = "Mark done"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Ring(ticked: ticked, size: size)
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(.press)
        .accessibilityLabel(ticked ? "Done" : label)
        .sensoryFeedback(.impact(weight: .light), trigger: ticked)
    }
}

/// A progress ring (36pt): the arc springs to its fraction; full, it turns solid and its check draws.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 36

    var body: some View {
        let full = fraction >= 1
        ZStack {
            Circle().fill(full ? Palette.tomato : Color.clear)
                .animation(.easeOut(duration: 0.3).delay(0.25), value: full)
            Circle().stroke(full ? Palette.tomato : Palette.tomato.opacity(0.2), lineWidth: 3.2)
                .padding(1.6)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(Palette.tomato, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.6)
                .animation(.spring(k: 170, c: 14), value: fraction)
            SVGShape(d: "M11 18.5l4.5 4.5L25 13.5")
                .trim(from: 0, to: full ? 1 : 0)
                .stroke(Palette.cream, style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .frame(width: 36, height: 36)
                .scaleEffect(size / 36)
                .frame(width: size, height: size)
                .animation(.curve(0.6, 0, 0.3, 1, 0.35).delay(0.45), value: full)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityValue(full ? "All done" : "\(Int((fraction * 100).rounded())) percent")
    }
}

// MARK: - Buttons

enum ButtonKind { case filled, outlined }

/// Capsule buttons: 44 tall (small 36, wide 54), Archivo 800. On tomato they turn cream.
struct CapsuleStyle: ButtonStyle {
    var kind: ButtonKind = .filled
    var small = false
    var wide = false
    var onTomato = false
    /// Overrides the colours (check-in on plum, marigold).
    var fill: Color? = nil
    var ink: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        let base = onTomato ? Palette.cream : Palette.tomato
        let other = onTomato ? Palette.tomato : Palette.cream
        let bg = fill ?? (kind == .filled ? base : Color.clear)
        let fg = ink ?? (kind == .filled ? other : base)
        let height: CGFloat = wide ? 54 : (small ? 36 : 44)
        configuration.label
            .type(small ? .buttonSmall : (wide ? TypeStyle.button.with(size: 16) : .button))
            .foregroundStyle(fg)
            .lineLimit(1)
            .padding(.horizontal, small ? 15 : 20)
            .frame(maxWidth: wide ? .infinity : nil)
            .frame(minHeight: height)
            .background(Capsule().fill(bg))
            .overlay {
                if kind == .outlined { Capsule().strokeBorder(fg, lineWidth: 1.7) }
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CapsuleStyle {
    static var filled: CapsuleStyle { CapsuleStyle(kind: .filled) }
    static var outlined: CapsuleStyle { CapsuleStyle(kind: .outlined) }
    static var filledSmall: CapsuleStyle { CapsuleStyle(kind: .filled, small: true) }
    static var outlinedSmall: CapsuleStyle { CapsuleStyle(kind: .outlined, small: true) }
    static var wide: CapsuleStyle { CapsuleStyle(kind: .filled, wide: true) }
}

/// Icon + label for a capsule button; the icon plays when tapped.
struct ButtonLabel: View {
    let title: String
    var icon: Icon? = nil
    var trigger = 0
    var small = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                AnimatedIcon(icon, size: small ? 15 : 17, trigger: trigger)
            }
            Text(title)
        }
    }
}

/// A capsule button that plays its icon when tapped.
struct ActionButton: View {
    let title: String
    var icon: Icon? = nil
    var style: CapsuleStyle = .filled
    let action: () -> Void
    @State private var play = 0

    var body: some View {
        Button {
            play += 1
            action()
        } label: {
            ButtonLabel(title: title, icon: icon, trigger: play, small: style.small)
        }
        .buttonStyle(style)
    }
}

/// A 44pt round button with an outline (Back, Settings, Close).
struct RoundButton: View {
    let icon: Icon
    let label: String
    var trigger = 0
    var filled: Color? = nil
    var ink: Color? = nil
    let action: () -> Void
    @State private var play = 0

    var body: some View {
        Button {
            play += 1
            action()
        } label: {
            AnimatedIcon(icon, size: 20, trigger: play + trigger)
                .foregroundStyle(ink.map { AnyShapeStyle($0) } ?? AnyShapeStyle(ForegroundStyle()))
                .frame(width: 44, height: 44)
                .background { if let filled { Circle().fill(filled) } }
                .overlay { if filled == nil { Circle().strokeBorder(lineWidth: 1.7) } }
                .contentShape(Circle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(label)
    }
}

// MARK: - Hero card

/// The one most likely action, big: a 29pt title, a subtitle (tomatoInk when late) and one or two buttons.
struct HeroCard<Buttons: View>: View {
    let title: String
    var subtitle: String = ""
    var late = false
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .type(.heroTitle)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .type(late ? TypeStyle.rowSub.with(size: 14).withWeight(700) : TypeStyle.rowSub.with(size: 14))
                    .foregroundStyle(late ? Palette.tomatoInk : Palette.inkSoft)
                    .padding(.top, 6)
            }
            HStack(spacing: 8) { buttons }
                .padding(.top, 14)
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        .padding(.bottom, 18)
    }
}

// MARK: - Tile (Move)

struct Tile: View {
    let icon: Icon
    let title: String
    let status: String
    var alert = false
    var trigger = 0
    let action: () -> Void
    @State private var play = 0

    var body: some View {
        Button {
            play += 1
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    AnimatedIcon(icon, size: 22, trigger: play + trigger)
                        .foregroundStyle(Palette.tomato)
                    Spacer(minLength: 6)
                    Text(status)
                        .type(.tileStatus)
                        .foregroundStyle(alert ? Palette.tomatoInk : Palette.ink.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 2)
                Text(title).type(.tile).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .strokeBorder(Palette.tileRule, lineWidth: 1.6))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        }
        .buttonStyle(.pressTile)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(status)")
    }
}

// MARK: - Segments and pills

/// An underline segmented control: the bar slides (0.42s with a little overshoot).
struct Segments<V: Hashable>: View {
    struct Item {
        let value: V
        let title: String
        var count: Int? = nil
    }

    let items: [Item]
    @Binding var selection: V
    var tight = false
    @Namespace private var ns

    var body: some View {
        HStack(spacing: tight ? 2 : 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.value == selection
                Button {
                    guard !on else { return }
                    withAnimation(Motion.indicator.rm) { selection = item.value }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.title).type(TypeStyle(size: tight ? 15 : 16, wght: 800, relativeTo: .subheadline))
                        if let count = item.count {
                            Text("\(count)").type(TypeStyle(size: tight ? 15 : 16, wght: 600, relativeTo: .subheadline)).opacity(0.8)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Palette.ink)
                    .opacity(on ? 1 : 0.45)
                    .padding(.horizontal, tight ? 7 : 10)
                    .frame(minHeight: 48)
                    .overlay(alignment: .bottom) {
                        if on {
                            Capsule().fill(Palette.tomato)
                                .frame(height: 3)
                                .padding(.horizontal, 10)
                                .offset(y: 0.75)
                                .matchedGeometryEffect(id: "bar", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
        .padding(.horizontal, -Metrics.sheetSide)
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// +1 when the selection moved right, −1 when it moved left.
    static func direction(from old: V, to new: V, in items: [Item]) -> CGFloat {
        let a = items.firstIndex { $0.value == old } ?? 0
        let b = items.firstIndex { $0.value == new } ?? 0
        return b >= a ? 1 : -1
    }
}

/// Filter pills: a tomato pill slides under the selected one.
struct Pills<V: Hashable>: View {
    struct Item {
        let value: V
        let title: String
        var count: Int? = nil
    }

    let items: [Item]
    @Binding var selection: V
    var tight = false
    @Namespace private var ns

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    let on = item.value == selection
                    Button {
                        guard !on else { return }
                        withAnimation(Motion.indicator.rm) { selection = item.value }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(item.title).type(TypeStyle(size: tight ? 14 : 14.5, wght: 800, relativeTo: .subheadline))
                            if let count = item.count {
                                Text("\(count)").type(TypeStyle(size: tight ? 14 : 14.5, wght: 600, relativeTo: .subheadline)).opacity(0.6)
                            }
                        }
                        .lineLimit(1)
                        .foregroundStyle(on ? Palette.cream : Palette.ink)
                        .padding(.horizontal, tight ? 11 : 14)
                        .frame(minHeight: 38)
                        .background {
                            if on {
                                Capsule().fill(Palette.tomato).matchedGeometryEffect(id: "pill", in: ns)
                            } else {
                                Capsule().strokeBorder(Palette.chipRule, lineWidth: 1.6)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, Metrics.sheetSide)
        }
        .padding(.horizontal, -Metrics.sheetSide)
        .padding(.bottom, 10)
        .sensoryFeedback(.selection, trigger: selection)
    }

    static func direction(from old: V, to new: V, in items: [Item]) -> CGFloat {
        let a = items.firstIndex { $0.value == old } ?? 0
        let b = items.firstIndex { $0.value == new } ?? 0
        return b >= a ? 1 : -1
    }
}

private struct SlideValue {
    var x: CGFloat = 0
    var opacity: Double = 1
}

extension View {
    /// The list slides in from ±40pt in the direction of travel each time `trigger` changes (380ms).
    func slideIn(_ trigger: Int, direction: CGFloat) -> some View {
        keyframeAnimator(initialValue: SlideValue(), trigger: trigger) { view, v in
            view.offset(x: v.x).opacity(v.opacity)
        } keyframes: { _ in
            let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.85), endControlPoint: UnitPoint(x: 0.25, y: 1))
            KeyframeTrack(\.x) {
                MoveKeyframe(direction * 40)
                LinearKeyframe(0, duration: 0.38, timingCurve: curve)
            }
            KeyframeTrack(\.opacity) {
                MoveKeyframe(0)
                LinearKeyframe(1, duration: 0.38, timingCurve: curve)
            }
        }
    }
}

// MARK: - Avatar, document box, search

/// Initials in a 44pt circle with a tomato outline.
struct Avatar: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let letters = name.split(separator: " ").filter { $0.first?.isLetter ?? false }.prefix(2)
            .compactMap(\.first).map { String($0) }.joined().uppercased()
        Text(letters.isEmpty ? "?" : letters)
            .type(TypeStyle(size: 14.5, wght: 800, tracking: 0.02, relativeTo: nil))
            .foregroundStyle(Palette.tomato)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Palette.tomato, lineWidth: 1.7))
            .accessibilityHidden(true)
    }
}

/// A 44pt document box: dashed when the paper is missing, solid tomato once it's in.
struct DocBox: View {
    let icon: Icon
    var missing = false
    var got = false
    var trigger = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.docRadius, style: .continuous)
                .fill(got ? Palette.tomato : Color.clear)
            RoundedRectangle(cornerRadius: Metrics.docRadius, style: .continuous)
                .strokeBorder(Palette.tomato, style: StrokeStyle(lineWidth: 1.7, dash: missing ? [4, 3] : []))
            if got {
                AnimatedIcon(.check, size: 22, trigger: trigger).foregroundStyle(Palette.cream)
            } else {
                AnimatedIcon(icon, size: 22, trigger: trigger).foregroundStyle(Palette.tomato)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

/// A capsule search field with a tomato magnifier that hops.
struct SearchField: View {
    @Binding var text: String
    var prompt = "Search"
    @State private var play = 0
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            AnimatedIcon(.search, size: 18, trigger: play).foregroundStyle(Palette.tomato)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Palette.inkFaint))
                .type(TypeStyle(size: 15.5, wght: 600, relativeTo: .body))
                .foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    AnimatedIcon(.x, size: 14).foregroundStyle(Palette.inkSoft).frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.18), lineWidth: 1.6))
        .contentShape(Capsule())
        .onTapGesture { focused = true }
        .onChange(of: focused) { _, on in if on { play += 1 } }
        .padding(.bottom, 4)
    }
}

// MARK: - Toast

/// An ink capsule with a blush check: drops in 14pt with an overshoot, holds 2.2s and fades.
struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            AnimatedIcon(.check, size: 18, trigger: text.hashValue).foregroundStyle(Palette.blush)
            Text(text).type(TypeStyle(size: 14, wght: 700, relativeTo: nil)).lineLimit(1)
        }
        .foregroundStyle(Palette.cream)
        .padding(.leading, 12)
        .padding(.trailing, 18)
        .frame(height: 40)
        .background(Capsule().fill(Palette.ink))
        .accessibilityElement(children: .combine)
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

/// "Thu", "3 Nov": the short "when" on the right of a row.
func whenText(_ d: Date?) -> String {
    guard let d else { return "No date" }
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInTomorrow(d) { return "Tomorrow" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 0
    if days > 1 && days < 7 { return d.formatted(.dateTime.weekday(.abbreviated)) }
    return d.formatted(.dateTime.day().month(.abbreviated))
}

func longDate(_ d: Date) -> String {
    d.formatted(date: .abbreviated, time: .omitted)
}

/// "2 weeks ago", "yesterday".
func relativeDate(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "today" }
    if cal.isDateInYesterday(d) { return "yesterday" }
    return d.formatted(.relative(presentation: .named))
}

/// Euros, whole numbers when possible.
func euros(_ cents: Int) -> String { Money.text(cents, "EUR") }

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
