import SwiftUI

/// The shared design tokens from app/design/tokens.json, in Swift. Same values as the Windows helper.
enum Palette {
    static let background = Color(hex: 0xFBF6EA)
    static let paper = Color(hex: 0xFFFDF7)
    static let ink = Color(hex: 0x111111)
    static let muted = Color(hex: 0x6E6A60)
    static let hairline = Color(hex: 0xE4DCC8)
    static let altRow = Color(hex: 0xFFF9EC)
    static let softYellow = Color(hex: 0xFFF3C4)
    static let softPink = Color(hex: 0xFFE1E8)
    static let danger = Color(hex: 0xFF4F7B)
    static let ok = Color(hex: 0x2DBE4E)
}

enum Accent: String, CaseIterable {
    case yellow, pink, green, lime, purple, sand, grey

    var color: Color {
        switch self {
        case .yellow: Color(hex: 0xFFD21F)
        case .pink: Color(hex: 0xFF4F7B)
        case .green: Color(hex: 0x2DBE4E)
        case .lime: Color(hex: 0xA4E22F)
        case .purple: Color(hex: 0x7B61FF)
        case .sand: Color(hex: 0xFFE08A)
        case .grey: Color(hex: 0x9A9A9A)
        }
    }

    /// Text on top of this accent: white reads better on purple, ink everywhere else.
    var onColor: Color { self == .purple ? .white : Palette.ink }
}

enum Metrics {
    static let border: CGFloat = 2.5
    static let borderThin: CGFloat = 1.5
    static let shadow: CGFloat = 5
    static let shadowSmall: CGFloat = 3
    static let radius: CGFloat = 10
    static let radiusSmall: CGFloat = 7
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Familjen Grotesk if it's bundled (Resources/Fonts), otherwise the system's bold sans.
enum Typeface {
    static func heading(_ size: CGFloat) -> Font {
        UIFontAvailable.familjen ? .custom("FamiljenGrotesk-Bold", size: size) : .system(size: size, weight: .black)
    }
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        UIFontAvailable.familjen ? .custom("FamiljenGrotesk-Regular", size: size).weight(weight) : .system(size: size, weight: weight)
    }
}

private enum UIFontAvailable {
    static let familjen: Bool = UIFont(name: "FamiljenGrotesk-Bold", size: 12) != nil
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
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
