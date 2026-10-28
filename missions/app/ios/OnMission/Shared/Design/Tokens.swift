import SwiftUI
import UIKit
import CoreText

/// The design tokens, in the look of the web app (missions/app/web/assets/app.css): the Tomato Flood screens
/// drawn in hesent.me's paper and ink (missions/site/public/assets/tokens.css). Posters are deeper paper,
/// the sheet is paper, everything is drawn in ink, and sage marks what is done.
enum Palette {
    /// The sheet, whole paper pages, and text on ink.
    static let paper = Color(hex: 0xF4EDE1)
    /// The tab bar under a poster, insets and the Arrange card.
    static let paperDeep = Color(hex: 0xE9DFCE)
    /// Text, line art, primary buttons, the active pill, rings and outlines.
    static let ink = Color(hex: 0x1E1A17)
    /// The poster: paper a shade deeper, with the paper texture multiplied in.
    static let flood = Color(hex: 0xEFE6D6)

    static let sage = Color(hex: 0x8BA374)
    /// Done: ticked rings, full progress, papers in the vault, money in. Tile icons and asides.
    static let sageDeep = Color(hex: 0x5C7448)
    static let sky = Color(hex: 0xA9CCE0)
    /// The caret, focus, the SOLD stamp and the flame.
    static let coral = Color(hex: 0xE5774A)
    static let pink = Color(hex: 0xEE9AA8)
    /// The "Answered!" flood and the "Thinking" check-in.
    static let ochre = Color(hex: 0xD9A13B)
    /// Late and missing.
    static let error = Color(hex: 0xA8481F)

    /// Row dividers (1.5pt).
    static let rule = Color(hex: 0x1E1A17, opacity: 0.16)
    /// Move tile outline (1.5pt).
    static let tileRule = Color(hex: 0x1E1A17, opacity: 0.35)
    /// Unselected chip and pill outline (1.5pt).
    static let chipRule = Color(hex: 0x1E1A17, opacity: 0.22)
    /// Row subtitles.
    static let inkSoft = Color(hex: 0x1E1A17, opacity: 0.68)
    /// Section counts and placeholders.
    static let inkFaint = Color(hex: 0x1E1A17, opacity: 0.55)
    /// The sheet's top edge.
    static let sheetEdge = Color(hex: 0x1E1A17, opacity: 0.85)
}

enum Metrics {
    static let sheetRadius: CGFloat = 30
    static let tileRadius: CGFloat = 20
    static let docRadius: CGFloat = 13
    static let stampRadius: CGFloat = 8
    /// Line art stroke.
    static let line: CGFloat = 2
    /// Outlines of buttons, chips, avatars and boxes.
    static let outline: CGFloat = 1.5
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

/// Archivo (variable, wdth 62–125, wght 100–900), bundled in Resources/Fonts. The only face, as on hesent.me.
enum TF {
    /// PostScript name of the default instance of the bundled variable font.
    static let archivoName = "Archivo-SemiBold"

    private static let wghtAxis = NSNumber(value: 0x77676874 as UInt32)
    private static let wdthAxis = NSNumber(value: 0x77647468 as UInt32)
    private static var cache: [String: UIFont] = [:]

    static let hasArchivo: Bool = UIFont(name: archivoName, size: 12) != nil

    /// The font at one width and weight, built through the variation axes.
    static func uiFont(size: CGFloat, wdth: CGFloat = 100, wght: CGFloat) -> UIFont {
        let key = "(size)|(wdth)|(wght)"
        if let hit = cache[key] { return hit }
        let made: UIFont
        if let base = UIFont(name: archivoName, size: size) {
            let axes: [NSNumber: NSNumber] = [wghtAxis: NSNumber(value: Double(wght)), wdthAxis: NSNumber(value: Double(wdth))]
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

    static func font(size: CGFloat, wdth: CGFloat = 100, wght: CGFloat) -> Font {
        Font(uiFont(size: size, wdth: wdth, wght: wght) as CTFont)
    }
}

/// One text style: size, axes, tracking (in em), case, and what it scales with.
struct TypeStyle {
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

    /// Display: the one big thing, Archivo narrowed to 75 and set tight, in sentence case (.disp on the web).
    static func disp(_ size: CGFloat) -> TypeStyle {
        TypeStyle(size: size, wdth: 75, wght: 820, tracking: -0.045, relativeTo: nil)
    }
    /// Asides. Once a handwriting face; like the web app it is Archivo 650 at the handwriting's x-height,
    /// so `size` is still the handwriting size and the letters come out at about two thirds of it.
    static func hand(_ size: CGFloat) -> TypeStyle {
        TypeStyle(size: (size * handScale * 2).rounded() / 2, wght: 650, tracking: -0.02, relativeTo: nil)
    }
    /// Archivo's x-height (0.526 em) brought to the handwriting's 0.34 em (font-size-adjust: .34 on the web).
    static let handScale: CGFloat = 0.34 / 0.526
    /// The line under each big number.
    static let cap = TypeStyle(size: 19, wght: 650, tracking: -0.01, relativeTo: nil)
    static let heroTitle = TypeStyle(size: 27, wght: 820, tracking: -0.035, relativeTo: .title)
    static let prayer = TypeStyle(size: 32, wght: 820, tracking: -0.04, relativeTo: nil)
    static let entry = TypeStyle(size: 32, wght: 820, tracking: -0.04, relativeTo: .largeTitle)
    static let kicker = TypeStyle(size: 15, wght: 650, relativeTo: nil)
    /// "Next up", "This week": a bold heading in sentence case.
    static let section = TypeStyle(size: 17, wght: 820, tracking: -0.02, relativeTo: .headline)
    static let count = TypeStyle(size: 13, wght: 600, relativeTo: .footnote)
    static let rowTitle = TypeStyle(size: 16.5, wght: 700, relativeTo: .body)
    static let rowSub = TypeStyle(size: 13, wght: 500, relativeTo: .footnote)
    static let when = TypeStyle(size: 13, wght: 700, relativeTo: .footnote)
    /// Capsule buttons are light, like the site's.
    static let button = TypeStyle(size: 15, wght: 500, relativeTo: .subheadline)
    static let buttonSmall = TypeStyle(size: 14, wght: 500, relativeTo: .subheadline)
    /// Links, chips, pills, segments and labels.
    static let label = TypeStyle(size: 15, wght: 650, relativeTo: .subheadline)
    static let tab = TypeStyle(size: 14.5, wght: 650, relativeTo: nil)
    static let body = TypeStyle(size: 15.5, wght: 500, relativeTo: .body)
    static let bodyBold = TypeStyle(size: 15.5, wght: 700, relativeTo: .body)
    static let small = TypeStyle(size: 13, wght: 600, relativeTo: .footnote)
    static let tile = TypeStyle(size: 15.5, wght: 650, relativeTo: .subheadline)
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
            .font(TF.font(size: size, wdth: style.wdth, wght: style.wght))
            .tracking(style.tracking * size)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Sets the font, tracking and case of a text style. Sizes follow Dynamic Type unless the style is fixed.
    func type(_ style: TypeStyle) -> some View { modifier(TypeStyleModifier(style: style)) }
}

/// Vertical metrics of Archivo, for placing text the way the web app's CSS line boxes do.
enum FontMetrics {
    /// (ascender + descender) / em.
    static let content: CGFloat = 1.088

    /// How far a SwiftUI text frame sits from the top of a CSS line box of `lineHeight`.
    static func shift(size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - content) * size / 2
    }

    /// Spacing between stacked lines to get a CSS `line-height` below the font's own.
    static func lineGap(size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        (lineHeight - content) * size
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

// MARK: - Paper and illustrations

/// Loads an image bundled in Resources (copied flat, or kept in its folder), WebP included.
enum BundledImage {
    private static var cache: [String: UIImage] = [:]

    /// `scale` is how many pixels make a point: the 1024px paper texture tiles at 512pt, like the web's.
    static func named(_ name: String, ext: String = "webp", folder: String? = nil, scale: CGFloat = 1) -> UIImage? {
        if let hit = cache[name] { return hit }
        let url = Bundle.main.url(forResource: name, withExtension: ext)
            ?? folder.flatMap { Bundle.main.url(forResource: name, withExtension: ext, subdirectory: $0) }
        guard let url, let data = try? Data(contentsOf: url), let image = UIImage(data: data, scale: scale) else { return nil }
        cache[name] = image
        return image
    }
}

/// hesent.me's paper texture (Resources/Texture/paper.webp, from the web app): the sheet and paper pages
/// show it as it is; posters multiply it into the deeper paper.
struct Paper: View {
    var color: Color = Palette.paper
    /// Posters multiply the texture into their colour; sheets lay it on top.
    var multiply = false

    var body: some View {
        ZStack {
            color
            if let tex = BundledImage.named("paper", folder: "Texture", scale: 2) {
                Image(uiImage: tex)
                    .resizable(resizingMode: .tile)
                    .blendMode(multiply ? .multiply : .normal)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// The paper texture behind a view, filling the safe areas too.
    func paper(_ color: Color = Palette.paper, multiply: Bool = false) -> some View {
        background(Paper(color: color, multiply: multiply).ignoresSafeArea())
    }
}

/// The illustrations from the web app and hesent.me (Resources/Art): the traveller with his backpack,
/// the mountains and a flower. Drawn in colour, never redrawn in code.
enum Illustration: String {
    case travellerWalk = "traveller-walk"
    case travellerRead = "traveller-read"
    case travellerWrite = "traveller-write"
    case travellerPray = "traveller-pray"
    case travellerPhoto = "traveller-photo"
    case travellerWave = "traveller-wave"
    case mountains
    case flowerPink = "flower-pink"
}

/// An illustration at a height, its width following the picture. It rises in with the poster.
struct Picture: View {
    let illustration: Illustration
    var height: CGFloat
    /// Leans the picture a little, like the prints on hesent.me.
    var tilt: Double = 0

    init(_ illustration: Illustration, height: CGFloat, tilt: Double = 0) {
        self.illustration = illustration
        self.height = height
        self.tilt = tilt
    }

    var body: some View {
        Group {
            if let image = BundledImage.named(illustration.rawValue, folder: "Art", scale: 2) {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(height: height)
        .rotationEffect(.degrees(tilt))
        .accessibilityHidden(true)
    }
}
