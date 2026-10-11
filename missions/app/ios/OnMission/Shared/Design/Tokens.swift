import SwiftUI

/// The shared design tokens from app/design/tokens.json ("Mocha & Ollie"), in Swift.
/// Mocha surfaces with light text; cream only for the one focal card per screen.
enum Palette {
    static let backgroundTop = Color(hex: 0x65493D)
    static let backgroundBottom = Color(hex: 0x53403A)
    static let background = Color(hex: 0x5C443B)
    static let gradient = LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    /// Card surface.
    static let paper = Color(hex: 0x735648)
    /// Text on mocha.
    static let ink = Color(hex: 0xFCEEE2)
    static let muted = Color(hex: 0xD9BFAC)
    static let hairline = Color(hex: 0xFFF4E8, opacity: 0.10)
    static let altRow = Color(hex: 0x6B5043)
    static let chip = Color(hex: 0xFFF4E8, opacity: 0.14)
    static let ring = Color(hex: 0xFFF4E8, opacity: 0.35)
    static let stitch = Color(hex: 0xCDE1D6, opacity: 0.38)
    static let softYellow = Color(hex: 0x7A5E4E)
    static let softPink = Color(hex: 0x7D5450)
    static let danger = Color(hex: 0xE8907F)
    static let ok = Color(hex: 0xAFBC6A)
    /// Dark text on any accent.
    static let onAccent = Color(hex: 0x24302C)
    /// Small area labels on mocha.
    static let tag = Color(hex: 0xB3C9BD)
    static let tabBar = Color(hex: 0x4E392F)
    static let tabIcon = Color(hex: 0xBFA390)
    static let doneInk = Color(hex: 0x2F3A12)
}

/// The cream focal card and its own ink.
enum Cream {
    static let fill = Color(hex: 0xFFF4E8)
    static let ink = Color(hex: 0x4A3329)
    static let sub = Color(hex: 0x8A6C5C)
    static let tag = Color(hex: 0x2F7D74)
    static let button = Color(hex: 0xF3E3D3)
    static let stitch = Color(hex: 0x4A3329, opacity: 0.22)
}

/// Accent slots keep their old names so every screen keeps its colour role; "yellow" is now Ollie's sage.
enum Accent: String, CaseIterable {
    case yellow, pink, green, lime, purple, sand, grey

    var color: Color {
        switch self {
        case .yellow: Color(hex: 0xB3C9BD)
        case .pink: Color(hex: 0xEDB3AE)
        case .green: Color(hex: 0xAFBC6A)
        case .lime: Color(hex: 0xC9D19A)
        case .purple: Color(hex: 0xC7B8DD)
        case .sand: Color(hex: 0xF3D9A0)
        case .grey: Color(hex: 0xBFA390)
        }
    }

    /// Text on top of this accent.
    var onColor: Color { Palette.onAccent }
}

enum Metrics {
    /// No outlines or hard shadows any more; these stay so layouts keep compiling.
    static let border: CGFloat = 0
    static let borderThin: CGFloat = 0
    static let shadow: CGFloat = 0
    static let shadowSmall: CGFloat = 0
    static let radius: CGFloat = 20
    static let radiusSmall: CGFloat = 14
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// DM Sans (bundled in Resources/Fonts), 18 max except big numbers; Lora italic for thanks and prayers.
enum Typeface {
    static func heading(_ size: CGFloat) -> Font {
        dm("DMSans-Bold", min(size, 18), .bold)
    }
    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "DMSans-Bold"
        case .semibold: name = "DMSans-SemiBold"
        case .medium: name = "DMSans-Medium"
        default: name = "DMSans-Regular"
        }
        return dm(name, min(size, 18), weight)
    }
    /// Big figures (support total, countdown).
    static func number(_ size: CGFloat = 26) -> Font {
        dm("DMSans-Bold", size, .bold).monospacedDigit()
    }
    /// Small uppercase label.
    static let cap: Font = dm("DMSans-Bold", 10.5, .bold)
    static func serif(_ size: CGFloat = 18) -> Font {
        UIFontAvailable.lora ? .custom("Lora-MediumItalic", size: size) : .system(size: size, weight: .medium, design: .serif).italic()
    }

    private static func dm(_ name: String, _ size: CGFloat, _ weight: Font.Weight) -> Font {
        UIFontAvailable.dmSans ? .custom(name, size: size) : .system(size: size, weight: weight)
    }
}

private enum UIFontAvailable {
    static let dmSans: Bool = UIFont(name: "DMSans-Bold", size: 12) != nil
    static let lora: Bool = UIFont(name: "Lora-MediumItalic", size: 12) != nil
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Ollie, from Ruben's own character sheet (Resources/Ollie). Never redrawn in code.
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

/// Which accent each section uses (tokens.json "accentFor").
extension AppSection {
    var accent: Accent {
        switch self {
        case .today, .tasks: .yellow
        case .checklists, .packing: .lime
        case .partners, .newsletters: .pink
        case .documents, .prayer: .purple
        case .budget: .green
        case .selling, .notes: .sand
        case .contacts, .search, .settings, .guides: .grey
        }
    }
}
