import SwiftUI

// The single-weight line drawings on the posters, with the prototype's exact geometry, in ink as the web app
// draws them. Strokes are 2 with round caps and joins; closed shapes fill with the poster's paper (they knock out)
// or with the lighter sheet paper (they glow). Each path draws itself in when the screen appears (handoff §9 "draw").

enum ArtFill { case none, flood, glow }

struct ArtPath {
    let d: String
    var fill: ArtFill = .none
    /// A dotted guide line: fades in instead of drawing.
    var dots = false
    var dash: [CGFloat] = [1, 7]
    var width: CGFloat? = nil

    static func line(_ d: String) -> ArtPath { ArtPath(d: d) }
    static func flood(_ d: String) -> ArtPath { ArtPath(d: d, fill: .flood) }
    static func glow(_ d: String) -> ArtPath { ArtPath(d: d, fill: .glow) }
    static func dots(_ d: String, gap: CGFloat = 7) -> ArtPath { ArtPath(d: d, dots: true, dash: [1, gap]) }
}

struct Drawing {
    let width: CGFloat
    let height: CGFloat
    let paths: [ArtPath]
    var lineWidth: CGFloat = Metrics.line
}

/// Colours of a drawing: line, the flood fill (knock out) and the glow fill (.bgf and .crf on the web).
struct ArtInk {
    var line: Color = Palette.ink
    var flood: Color = Palette.flood
    var glow: Color = Palette.paper

    static let onPoster = ArtInk()
    static let onPaper = ArtInk(line: Palette.ink, flood: Palette.paper, glow: Palette.paper)
    /// The Answered flood: the sun fills ochre-gold on ochre, as on the web.
    static let onGold = ArtInk(line: Palette.ink, flood: Palette.ochre, glow: Palette.paper)
}

/// Draws a `Drawing`, drawing itself in each time the screen's `entry` changes (or `trigger`, when given).
struct LineArt: View {
    let drawing: Drawing
    var ink: ArtInk = .onPoster
    /// Extra delay after the screen's own entry delay.
    var delay: Double = 0.12
    /// Overrides the screen's entry trigger (Capture redraws per kind).
    var trigger: Int? = nil
    var drawDuration: Double = 0.9
    var stagger: Double = 0.055

    @Environment(\.entry) private var entry
    @Environment(\.entryDelay) private var base

    var body: some View {
        let start = (trigger == nil ? base : 0) + delay
        let drawable = drawing.paths.filter { !$0.dots }.count
        let total = start + max(drawDuration + stagger * Double(drawable), 1.2) + 0.1
        Clock(trigger: trigger ?? entry, duration: total) { t in
            ArtCanvas(drawing: drawing, ink: ink, t: t - start, drawDuration: drawDuration, stagger: stagger)
        }
        .frame(width: drawing.width, height: drawing.height)
        .accessibilityHidden(true)
    }
}

/// A drawing at `t` seconds into its draw-in.
struct ArtCanvas: View {
    let drawing: Drawing
    let ink: ArtInk
    let t: Double
    var drawDuration: Double = 0.9
    var stagger: Double = 0.055

    private static let drawEase = Ease(0.6, 0, 0.3, 1)

    var body: some View {
        let paths = drawing.paths
        let order: [Int] = paths.indices.map { i in paths[..<i].filter { !$0.dots }.count }
        ZStack(alignment: .topLeading) {
            ForEach(Array(paths.enumerated()), id: \.offset) { i, art in
                let width = art.width ?? drawing.lineWidth
                let drawn = art.dots ? 1 : seg(t, Double(order[i]) * stagger, drawDuration, Self.drawEase)
                let shown = art.dots ? seg(t, 0.5, 0.7) : 1
                ZStack(alignment: .topLeading) {
                    switch art.fill {
                    case .flood: SVGShape(d: art.d).fill(ink.flood)
                    case .glow: SVGShape(d: art.d).fill(ink.glow)
                    case .none: EmptyView()
                    }
                    SVGShape(d: art.d)
                        .trim(from: 0, to: drawn)
                        .stroke(ink.line, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round,
                                                             dash: art.dots ? art.dash : []))
                        .opacity(shown)
                }
                .frame(width: drawing.width, height: drawing.height, alignment: .topLeading)
            }
        }
        .frame(width: drawing.width, height: drawing.height, alignment: .topLeading)
    }
}

// MARK: - The drawings

enum Art {
    /// Tasks: a clipboard with ticks.
    static let clipboard = Drawing(width: 112, height: 150, paths: [
        .flood("M14 22 C 40 20, 72 20, 98 23 C 102 24, 104 27, 104 31 L103 138 C 103 142, 100 145, 96 145 L16 146 C 11 146, 8 143, 8 138 L9 30 C 9 25, 11 23, 14 22 Z"),
        .glow("M36 14 L76 14 L78 30 L34 30 Z"),
        .line("M24 56 L32 64 L46 48"), .line("M56 58 L90 57"),
        .line("M24 88 L32 96 L46 80"), .line("M56 90 L86 89"),
        .line(SVG.circle(34, 120, 8)), .line("M56 121 L80 120"),
    ])

    /// People: the trail up the mountain (the walker and progress are drawn by the screen).
    static let trailPath = "M20 124 C 90 122, 116 98, 160 92 S 238 64, 280 46 S 334 22, 354 18"
    static let trail = Drawing(width: 390, height: 136, paths: [
        .dots(trailPath, gap: 8),
        .line("M354 18 L354 -10"), .glow("M354 -10 L374 -3 L354 4"),
        .line("M200 134 L248 96 L268 112 L300 78 L352 134"),
        .line("M290 88 L294 84 L300 89 L305 83 L310 88"),
    ])

    /// Answered: a sunrise.
    static let sunrise = Drawing(width: 200, height: 190, paths: [
        .flood(SVG.circle(100, 92, 34)),
        .line("M100 50 V32 M142 92 H160 M58 92 H40 M130 62 L142 50 M70 62 L58 50 M130 122 L142 134 M70 122 L58 134"),
        .line("M4 178 C 40 152, 70 148, 100 162 C 130 146, 166 148, 196 174"),
    ], lineWidth: 2.6)

    /// Move: the dotted arc from AMS to ZQN (the plane is drawn by the screen).
    static let arcPath = "M34 112 C 110 6, 280 6, 356 112"
    static let arc = Drawing(width: 390, height: 138, paths: [
        .dots(arcPath, gap: 8),
        .glow(SVG.circle(34, 112, 5)), .line(SVG.circle(356, 112, 5)),
    ])

    // Capture: one drawing per kind.
    static let captureTask = Drawing(width: 390, height: 160, paths: [
        .glow("M150 30 C 180 28, 220 28, 246 31 C 250 32, 252 35, 252 39 L251 140 C 251 144, 248 147, 244 147 L152 148 C 147 148, 144 145, 144 140 L145 38 C 145 33, 147 31, 150 30 Z"),
        .line("M162 62 L172 72 L190 54"), .line("M200 66 L236 65"),
        .line("M162 104 L172 114 L190 96"), .line("M200 108 L230 107"),
    ])
    static let capturePerson = Drawing(width: 390, height: 160, paths: [
        .line(SVG.circle(176, 62, 24)), .line("M130 146 C 134 112, 152 96, 176 96 S 218 112, 222 146"),
        .line(SVG.circle(238, 72, 18)), .line("M226 102 C 250 100, 266 118, 270 146"),
    ])
    static let captureHeart = Drawing(width: 390, height: 160, paths: [
        .glow("M195 146 C 195 146, 132 108, 132 64 A 32 32 0 0 1 195 50 A 32 32 0 0 1 258 64 C 258 108, 195 146, 195 146 Z"),
        .line("M168 72 C 176 62, 190 60, 196 70"),
    ])
    static let captureFlame = Drawing(width: 390, height: 160, paths: [
        .glow("M195 14 C 214 40, 236 56, 236 92 A 41 41 0 0 1 154 92 C 154 56, 176 40, 195 14 Z"),
        .line("M195 92 C 204 102, 211 109, 211 120 A 16 16 0 0 1 179 120 C 179 109, 186 102, 195 92 Z"),
    ])
    static let captureNote = Drawing(width: 390, height: 160, paths: [
        .glow("M146 30 L232 30 L250 48 L250 148 L146 148 Z"), .line("M232 30 L232 48 L250 48"),
        .line("M164 76 L230 76"), .line("M164 100 L222 100"), .line("M164 124 L204 124"),
    ])
    static let captureTag = Drawing(width: 390, height: 160, paths: [
        .line("M195 6 L195 30"),
        .glow("M166 46 L195 26 L224 46 L224 140 C 224 145, 220 148, 215 148 L175 148 C 170 148, 166 145, 166 140 Z"),
        .line(SVG.circle(195, 46, 5)),
        .line("M185 96 C 185 84, 205 84, 205 92 M181 104 L205 104 M181 114 L201 114 M205 116 C 205 126, 185 126, 185 112"),
    ])
    static let captureBag = Drawing(width: 390, height: 160, paths: [
        .line("M178 50 L178 32 C 178 28, 181 26, 185 26 L205 26 C 209 26, 212 28, 212 32 L212 50"),
        .glow(SVG.rect(148, 50, 94, 94, rx: 14)),
        .line("M174 50 L174 144 M216 50 L216 144"),
        .line(SVG.circle(164, 150, 5)), .line(SVG.circle(226, 150, 5)),
    ])

    /// Checklists: stepping stones up to a flag.
    static let stones = Drawing(width: 176, height: 230, paths: [
        .dots("M30 196 C 40 172, 62 170, 74 160 M74 160 C 86 134, 106 130, 116 118 M116 118 C 128 96, 144 90, 150 78"),
        .flood("M8 206 C 8 196, 52 196, 52 206 C 52 214, 8 214, 8 206 Z"),
        .flood("M54 166 C 54 156, 96 156, 96 166 C 96 174, 54 174, 54 166 Z"),
        .flood("M96 124 C 96 114, 138 114, 138 124 C 138 132, 96 132, 96 124 Z"),
        .flood("M130 82 C 130 72, 170 72, 170 82 C 170 90, 130 90, 130 82 Z"),
        .line("M150 78 L150 22"), .glow("M150 22 L172 30 L150 38"),
        .glow(SVG.circle(30, 196, 7)),
    ])

    /// Vault: a folder with a globe (the ALL IN stamp is drawn by the screen).
    static let folder = Drawing(width: 170, height: 240, paths: [
        .flood("M22 20 L132 14 C 140 14, 146 19, 146 27 L150 206 C 150 214, 145 219, 137 219 L28 224 C 20 224, 15 219, 15 211 L12 32 C 12 25, 16 20, 22 20 Z"),
        .line(SVG.circle(80, 96, 30)),
        .line("M50 96 L110 96 M80 66 C 66 80, 66 112, 80 126 M80 66 C 94 80, 94 112, 80 126"),
        .line("M46 156 L114 154"), .line("M58 176 L102 175"),
    ])

    /// Packing: the suitcase outline (the wavy fill is drawn by the screen).
    static let suitcase = Drawing(width: 140, height: 272, paths: [
        .line("M50 62 L50 34 C 50 28, 54 24, 60 24 L80 24 C 86 24, 90 28, 90 34 L90 62"),
        .line(SVG.rect(12, 62, 116, 186, rx: 16)),
        .line("M44 62 L44 248 M96 62 L96 248"),
        .line(SVG.circle(34, 258, 7)), .line(SVG.circle(106, 258, 7)),
    ])

    /// Guides: an open book (the turning page is drawn by the screen).
    static let bookRight = "M90 30 C 116 16, 146 14, 172 22 L172 140 C 146 132, 116 134, 90 148 Z"
    static let book = Drawing(width: 180, height: 160, paths: [
        .flood("M90 30 C 64 16, 34 14, 8 22 L8 140 C 34 132, 64 134, 90 148 Z"),
        .flood(bookRight),
        .line("M24 52 C 44 48, 62 50, 76 56 M24 74 C 44 70, 62 72, 76 78 M24 96 C 40 92, 56 94, 70 98"),
        .line("M104 52 C 118 48, 138 46, 156 50 M104 74 C 118 70, 138 68, 156 72"),
    ])

    /// Detail pages: a small card.
    static let card = Drawing(width: 110, height: 120, paths: [
        .flood("M14 16 L92 12 C 98 12, 102 16, 102 22 L104 104 C 104 110, 100 114, 94 114 L18 116 C 12 116, 8 112, 8 106 L6 24 C 6 19, 9 16, 14 16 Z"),
        .line("M26 44 L82 42"), .line("M26 64 L74 63"), .line("M26 84 L60 83"),
    ])
}
