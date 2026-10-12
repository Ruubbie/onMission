import SwiftUI
import UIKit
import CoreText

/// The shared design tokens from app/design/tokens.json ("Tomato Flood"), in Swift.
/// One big idea on tomato per screen; a calm cream sheet holds the rest.
enum Palette {
    /// The flood: poster backgrounds, primary buttons, the active pill, rings, line accents on cream.
    static let tomato = Color(hex: 0xD2462B)
    /// "Late" and alert text, and small tomato text on cream (5.3:1).
    static let tomatoInk = Color(hex: 0xB23A22)
    /// Sheets, cream pages, text and line art on tomato.
    static let cream = Color(hex: 0xFBF1E3)
    /// Text on cream and on marigold.
    static let ink = Color(hex: 0x2E1C16)
    /// The "Answered!" flood and the "Thinking" check-in.
    static let marigold = Color(hex: 0xE8A13A)
    /// The "Not now" check-in.
    static let plum = Color(hex: 0x4B3B52)
    /// The toast's check icon.
    static let blush = Color(hex: 0xF0A58F)

    /// Row dividers on cream (1.5pt).
    static let rule = Color(hex: 0xD2462B, opacity: 0.16)
    /// Move tile outline (1.6pt).
    static let tileRule = Color(hex: 0xD2462B, opacity: 0.35)
    /// Unselected chip and pill outline (1.6pt).
    static let chipRule = Color(hex: 0x2E1C16, opacity: 0.22)
    /// Row subtitles.
    static let inkSoft = Color(hex: 0x2E1C16, opacity: 0.68)
    /// Section counts and placeholders.
    static let inkFaint = Color(hex: 0x2E1C16, opacity: 0.55)
    /// Secondary text on tomato.
    static let creamSoft = Color(hex: 0xFBF1E3, opacity: 0.82)
    /// Inactive tab icons on tomato.
    static let creamFaint = Color(hex: 0xFBF1E3, opacity: 0.72)
}

enum Metrics {
    static let sheetRadius: CGFloat = 30
    static let tileRadius: CGFloat = 20
    static let docRadius: CGFloat = 13
    static let stampRadius: CGFloat = 8
    /// Line art stroke.
    static let line: CGFloat = 2.4
    /// Row dividers.
    static let rule: CGFloat = 1.5
    /// Left inset of posters and the top bar.
    static let gutter: CGFloat = 24
    /// Sheet padding: top and sides.
    static let sheetTop: CGFloat = 22
    static let sheetSide: CGFloat = 20
    /// The top bar sits under the status bar, 48 tall.
    static let topBar: CGFloat = 48
    /// Air between the top bar and the poster.
    static let air: CGFloat = 20
    /// The prototype's phone: posters are designed on a 390-wide canvas.
    static let designWidth: CGFloat = 390
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Type

/// Archivo (variable, wdth 62–125, wght 100–900) and Caveat (variable, wght 400–700), bundled in Resources/Fonts.
enum TF {
    enum Family { case archivo, caveat }

    /// PostScript names of the default instances of the bundled variable fonts.
    static let archivoName = "Archivo-SemiBold"
    static let caveatName = "Caveat-Regular"

    private static let wghtAxis = NSNumber(value: 0x77676874 as UInt32)
    private static let wdthAxis = NSNumber(value: 0x77647468 as UInt32)
    private static var cache: [String: UIFont] = [:]

    static let hasArchivo: Bool = UIFont(name: archivoName, size: 12) != nil
    static let hasCaveat: Bool = UIFont(name: caveatName, size: 12) != nil

    /// The font at one width and weight, built through the variation axes.
    static func uiFont(_ family: Family, size: CGFloat, wdth: CGFloat = 100, wght: CGFloat) -> UIFont {
        let key = "\(family)|\(size)|\(wdth)|\(wght)"
        if let hit = cache[key] { return hit }
        let made: UIFont
        let name = family == .archivo ? archivoName : caveatName
        if let base = UIFont(name: name, size: size) {
            var axes: [NSNumber: NSNumber] = [wghtAxis: NSNumber(value: Double(wght))]
            if family == .archivo { axes[wdthAxis] = NSNumber(value: Double(wdth)) }
            let attribute = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
            let descriptor = base.fontDescriptor.addingAttributes([attribute: axes])
            made = UIFont(descriptor: descriptor, size: size)
        } else {
            // Not bundled: the system font in a matching width keeps the look close.
            let width: UIFont.Width = wdth < 70 ? .compressed : (wdth < 90 ? .condensed : .standard)
            made = UIFont.systemFont(ofSize: size, weight: weight(wght), width: width)
        }
        cache[key] = made
        return made
    }

    private static func weight(_ w: CGFloat) -> UIFont.Weight {
        switch w {
        case ..<250: .thin
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }

    static func font(_ family: Family, size: CGFloat, wdth: CGFloat = 100, wght: CGFloat) -> Font {
        Font(uiFont(family, size: size, wdth: wdth, wght: wght) as CTFont)
    }
}

/// One text style: family, size, axes, tracking (in em), case, and what it scales with.
struct TypeStyle {
    var family: TF.Family = .archivo
    var size: CGFloat
    var wdth: CGFloat = 100
    var wght: CGFloat = 600
    /// Letter spacing in em.
    var tracking: CGFloat = 0
    var uppercase = false
    /// Scales with this text style; nil keeps the size fixed (posters).
    var relativeTo: Font.TextStyle? = .body

    func with(size: CGFloat) -> TypeStyle { var s = self; s.size = size; return s }
    func fixed() -> TypeStyle { var s = self; s.relativeTo = nil; return s }

    func scaledSize(_ dts: DynamicTypeSize) -> CGFloat {
        guard let relativeTo else { return size }
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dts))
        return UIFontMetrics(forTextStyle: relativeTo.uiStyle).scaledValue(for: size, compatibleWith: traits)
    }

    // Display: condensed black capitals for the one big thing.
    static func disp(_ size: CGFloat) -> TypeStyle {
        TypeStyle(size: size, wdth: 64, wght: 900, uppercase: true, relativeTo: nil)
    }
    // Hand: Caveat Bold for asides.
    static func hand(_ size: CGFloat) -> TypeStyle {
        TypeStyle(family: .caveat, size: size, wght: 700, relativeTo: nil)
    }
    /// The line under each big number.
    static let cap = TypeStyle(size: 21, wdth: 70, wght: 800, tracking: 0.06, uppercase: true, relativeTo: nil)
    static let heroTitle = TypeStyle(size: 29, wdth: 78, wght: 800, relativeTo: .title)
    static let prayer = TypeStyle(size: 35, wdth: 80, wght: 800, relativeTo: nil)
    static let entry = TypeStyle(size: 36, wdth: 78, wght: 800, relativeTo: .largeTitle)
    /// 15pt bold rather than the prototype's 12.5: cream on tomato only passes contrast at this size (handoff §13.3).
    static let kicker = TypeStyle(size: 15, wght: 800, tracking: 0.11, uppercase: true, relativeTo: nil)
    static let section = TypeStyle(size: 13, wght: 800, tracking: 0.13, uppercase: true, relativeTo: .footnote)
    static let count = TypeStyle(size: 13, wght: 700, tracking: 0.02, relativeTo: .footnote)
    static let rowTitle = TypeStyle(size: 16.5, wght: 700, relativeTo: .body)
    static let rowSub = TypeStyle(size: 13, wght: 500, relativeTo: .footnote)
    static let when = TypeStyle(size: 13, wght: 700, relativeTo: .footnote)
    static let button = TypeStyle(size: 15, wght: 800, relativeTo: .subheadline)
    static let buttonSmall = TypeStyle(size: 14, wght: 800, relativeTo: .subheadline)
    static let tab = TypeStyle(size: 14.5, wght: 800, relativeTo: nil)
    static let body = TypeStyle(size: 15.5, wght: 500, relativeTo: .body)
    static let bodyBold = TypeStyle(size: 15.5, wght: 700, relativeTo: .body)
    static let small = TypeStyle(size: 13, wght: 600, relativeTo: .footnote)
    static let tile = TypeStyle(size: 15.5, wght: 800, relativeTo: .subheadline)
    static let tileStatus = TypeStyle(size: 12.5, wght: 700, relativeTo: .caption)
    static let lead = TypeStyle(size: 18, wght: 600, relativeTo: .title3)
}

extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

private struct TypeStyleModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dts
    let style: TypeStyle

    func body(content: Content) -> some View {
        let size = style.scaledSize(dts)
        content
            .font(TF.font(style.family, size: size, wdth: style.wdth, wght: style.wght))
            .tracking(style.tracking * size)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Sets the font, tracking and case of a text style. Sizes follow Dynamic Type unless the style is fixed.
    func type(_ style: TypeStyle) -> some View { modifier(TypeStyleModifier(style: style)) }
}

/// Vertical metrics of the bundled fonts, for placing text the way the prototype's CSS line boxes do.
enum FontMetrics {
    /// (ascender + descender) / em.
    static func content(_ family: TF.Family) -> CGFloat { family == .archivo ? 1.088 : 1.26 }

    /// How far a SwiftUI text frame sits from the top of a CSS line box of `lineHeight`.
    static func shift(_ family: TF.Family, size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - content(family)) * size / 2
    }

    /// Spacing between stacked lines to get a CSS `line-height` below the font's own.
    static func lineGap(_ family: TF.Family, size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - content(family)) * size
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Mixes two sRGB colours (the check-in background follows the finger).
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func c(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        let k = min(max(t, 0), 1)
        return Color(.sRGB,
                     red: c(a, 16) + (c(b, 16) - c(a, 16)) * k,
                     green: c(a, 8) + (c(b, 8) - c(a, 8)) * k,
                     blue: c(a, 0) + (c(b, 0) - c(a, 0)) * k,
                     opacity: 1)
    }
}

/// Ollie, from Ruben's own character sheet (Resources/Ollie). Never redrawn in code; a rare cameo only.
enum OlliePose: String {
    case sit, hug, stand, sleep, side
}

struct Ollie: View {
    let pose: OlliePose
    var height: CGFloat = 60

    var body: some View {
        Group {
            if let img = UIImage(named: "ollie-\(pose.rawValue)") {
                Image(uiImage: img).resizable().interpolation(.high).scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
