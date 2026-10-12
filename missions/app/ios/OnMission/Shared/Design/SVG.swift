import SwiftUI

/// Turns SVG path data into a SwiftUI `Path`, so the Lucide icons and the line drawings keep the
/// prototype's exact geometry. Supports M L H V C S Q T A Z (absolute and relative).
enum SVG {
    private static var cache: [String: Path] = [:]

    static func path(_ d: String) -> Path {
        if let hit = cache[d] { return hit }
        let made = parse(d)
        cache[d] = made
        return made
    }

    // MARK: Shapes as path data

    static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> String {
        "M\(cx - r) \(cy) a\(r) \(r) 0 1 0 \(2 * r) 0 a\(r) \(r) 0 1 0 \(-2 * r) 0"
    }

    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, rx: Double = 0) -> String {
        guard rx > 0 else { return "M\(x) \(y) H\(x + w) V\(y + h) H\(x) Z" }
        let r = min(rx, w / 2, h / 2)
        return "M\(x + r) \(y) H\(x + w - r) A\(r) \(r) 0 0 1 \(x + w) \(y + r) V\(y + h - r) "
            + "A\(r) \(r) 0 0 1 \(x + w - r) \(y + h) H\(x + r) A\(r) \(r) 0 0 1 \(x) \(y + h - r) "
            + "V\(y + r) A\(r) \(r) 0 0 1 \(x + r) \(y) Z"
    }

    static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> String {
        "M\(x1) \(y1) L\(x2) \(y2)"
    }

    static func polyline(_ points: [Double]) -> String {
        stride(from: 0, to: points.count - 1, by: 2).enumerated().map { index, i in
            "\(index == 0 ? "M" : "L")\(points[i]) \(points[i + 1])"
        }.joined(separator: " ")
    }

    // MARK: Parsing

    private struct Scanner {
        let chars: [Character]
        var i = 0

        init(_ s: String) { chars = Array(s) }

        var atEnd: Bool {
            mutating get { skip(); return i >= chars.count }
        }

        mutating func skip() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" || chars[i] == "\r" {
                i += 1
            }
        }

        mutating func command() -> Character? {
            skip()
            guard i < chars.count else { return nil }
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" {
                i += 1
                return c
            }
            return nil
        }

        mutating func number() -> Double? {
            skip()
            let start = i
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
            var sawDigit = false, sawDot = false
            while i < chars.count {
                let c = chars[i]
                if c.isASCII && c.isNumber {
                    sawDigit = true
                    i += 1
                } else if c == "." && !sawDot {
                    sawDot = true
                    i += 1
                } else {
                    break
                }
            }
            if sawDigit, i < chars.count, chars[i] == "e" || chars[i] == "E" {
                var j = i + 1
                if j < chars.count, chars[j] == "-" || chars[j] == "+" { j += 1 }
                if j < chars.count, chars[j].isASCII && chars[j].isNumber {
                    i = j
                    while i < chars.count, chars[i].isASCII && chars[i].isNumber { i += 1 }
                }
            }
            guard sawDigit else {
                i = start
                return nil
            }
            return Double(String(chars[start..<i]))
        }

        mutating func flag() -> Bool? {
            skip()
            guard i < chars.count, chars[i] == "0" || chars[i] == "1" else { return nil }
            let on = chars[i] == "1"
            i += 1
            return on
        }

        /// The next thing is a number (so the last command repeats).
        mutating func numberAhead() -> Bool {
            skip()
            guard i < chars.count else { return false }
            let c = chars[i]
            return (c.isASCII && c.isNumber) || c == "-" || c == "+" || c == "."
        }
    }

    private static func parse(_ d: String) -> Path {
        var s = Scanner(d)
        var p = Path()
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint? = nil
        var lastQuad: CGPoint? = nil
        var cmd: Character = "M"

        while !s.atEnd {
            if let c = s.command() {
                cmd = c
            } else if !s.numberAhead() {
                break
            }
            let rel = cmd.isLowercase
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            }
            var cubic: CGPoint? = nil
            var quad: CGPoint? = nil

            switch cmd {
            case "M", "m":
                guard let x = s.number(), let y = s.number() else { return p }
                cur = pt(x, y)
                start = cur
                p.move(to: cur)
                // Further pairs are line-tos.
                cmd = rel ? "l" : "L"
            case "L", "l":
                guard let x = s.number(), let y = s.number() else { return p }
                cur = pt(x, y)
                p.addLine(to: cur)
            case "H", "h":
                guard let x = s.number() else { return p }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                p.addLine(to: cur)
            case "V", "v":
                guard let y = s.number() else { return p }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                p.addLine(to: cur)
            case "C", "c":
                guard let x1 = s.number(), let y1 = s.number(), let x2 = s.number(), let y2 = s.number(),
                      let x = s.number(), let y = s.number() else { return p }
                let c1 = pt(x1, y1), c2 = pt(x2, y2), end = pt(x, y)
                p.addCurve(to: end, control1: c1, control2: c2)
                cubic = c2
                cur = end
            case "S", "s":
                guard let x2 = s.number(), let y2 = s.number(), let x = s.number(), let y = s.number() else { return p }
                let c1 = lastCubic.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pt(x2, y2), end = pt(x, y)
                p.addCurve(to: end, control1: c1, control2: c2)
                cubic = c2
                cur = end
            case "Q", "q":
                guard let x1 = s.number(), let y1 = s.number(), let x = s.number(), let y = s.number() else { return p }
                let c = pt(x1, y1), end = pt(x, y)
                p.addQuadCurve(to: end, control: c)
                quad = c
                cur = end
            case "T", "t":
                guard let x = s.number(), let y = s.number() else { return p }
                let c = lastQuad.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let end = pt(x, y)
                p.addQuadCurve(to: end, control: c)
                quad = c
                cur = end
            case "A", "a":
                guard let rx = s.number(), let ry = s.number(), let rot = s.number(),
                      let large = s.flag(), let sweep = s.flag(), let x = s.number(), let y = s.number() else { return p }
                let end = pt(x, y)
                arc(&p, from: cur, to: end, rx: rx, ry: ry, angle: rot, large: large, sweep: sweep)
                cur = end
            case "Z", "z":
                p.closeSubpath()
                cur = start
            default:
                return p
            }
            lastCubic = cubic
            lastQuad = quad
        }
        return p
    }

    /// An elliptical arc as cubic curves (SVG implementation notes, F.6.5).
    private static func arc(_ p: inout Path, from p1: CGPoint, to p2: CGPoint, rx rx0: Double, ry ry0: Double,
                            angle: Double, large: Bool, sweep: Bool) {
        if p1 == p2 { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 {
            p.addLine(to: p2)
            return
        }
        let phi = angle * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (Double(p1.x) - Double(p2.x)) / 2
        let dy = (Double(p1.y) - Double(p2.y)) / 2
        let x1p = cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : max(0, num / den).squareRoot()
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = coef * -ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (Double(p1.x) + Double(p2.x)) / 2
        let cy = sinP * cxp + cosP * cyp + (Double(p1.y) + Double(p2.y)) / 2

        func angleBetween(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta1 = angleBetween(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var delta = angleBetween((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi } else if sweep && delta < 0 { delta += 2 * .pi }

        let count = max(Int((abs(delta) / (.pi / 2)).rounded(.up)), 1)
        let step = delta / Double(count)
        let k = 4.0 / 3.0 * tan(step / 4)
        func map(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: cx + rx * x * cosP - ry * y * sinP, y: cy + rx * x * sinP + ry * y * cosP)
        }
        var theta = theta1
        for _ in 0..<count {
            let c1 = cos(theta), s1 = sin(theta)
            let next = theta + step
            let c2 = cos(next), s2 = sin(next)
            p.addCurve(to: map(c2, s2), control1: map(c1 - k * s1, s1 + k * c1), control2: map(c2 + k * s2, s2 - k * c2))
            theta = next
        }
    }
}

/// One piece of SVG path data as a Shape, drawn in its own coordinates (put it in a frame the size of the viewBox).
struct SVGShape: Shape {
    let d: String

    func path(in rect: CGRect) -> Path { SVG.path(d) }
}

extension Path {
    /// The point `fraction` of the way along the path, and the direction there in degrees.
    func point(at fraction: CGFloat) -> (point: CGPoint, angle: Double) {
        let f = min(max(fraction, 0.0005), 1)
        let here = trimmedPath(from: 0, to: f).currentPoint ?? .zero
        let ahead = trimmedPath(from: 0, to: min(f + 0.004, 1)).currentPoint ?? here
        let back = trimmedPath(from: 0, to: max(f - 0.004, 0.0001)).currentPoint ?? here
        let a = ahead == here ? (here.x - back.x, here.y - back.y) : (ahead.x - here.x, ahead.y - here.y)
        return (here, atan2(Double(a.1), Double(a.0)) * 180 / .pi)
    }
}
