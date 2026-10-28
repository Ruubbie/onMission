import SwiftUI
import UIKit

// The motion system (handoff §9): shared curves, springs, rise, draw, and a clock for timed moments.
// Every curve is the prototype's CSS cubic-bezier; `spring(k, c)` is a mass-1 spring.

/// A CSS `cubic-bezier(x1, y1, x2, y2)` easing, evaluated on 0...1.
struct Ease {
    let x1, y1, x2, y2: Double

    init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
        self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2
    }

    func callAsFunction(_ t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        // x(s) is monotonic for control x in 0...1, so bisection always finds s.
        var lo = 0.0, hi = 1.0, s = t
        for _ in 0..<24 {
            s = (lo + hi) / 2
            if Self.bez(s, x1, x2) < t { lo = s } else { hi = s }
        }
        return Self.bez(s, y1, y2)
    }

    private static func bez(_ s: Double, _ a: Double, _ b: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
    }

    static let linear = Ease(0, 0, 1, 1)
    static let easeIn = Ease(0.42, 0, 1, 1)
    static let easeOut = Ease(0, 0, 0.58, 1)
    static let easeInOut = Ease(0.42, 0, 0.58, 1)
    /// countTo: an ease-out cubic.
    static let outCubic = Ease(0.33, 1, 0.68, 1)
}

/// A damped spring from 0 to 1 with mass 1 (the prototype's `spr(k, c)`).
struct Spring1 {
    let k: Double
    let c: Double

    func callAsFunction(_ t: Double) -> Double {
        if t <= 0 { return 0 }
        let w0 = k.squareRoot()
        let zeta = c / (2 * w0)
        if zeta < 1 {
            let wd = w0 * (1 - zeta * zeta).squareRoot()
            return 1 - exp(-zeta * w0 * t) * (cos(wd * t) + (zeta * w0 / wd) * sin(wd * t))
        } else if zeta == 1 {
            return 1 - exp(-w0 * t) * (1 + w0 * t)
        } else {
            let root = (zeta * zeta - 1).squareRoot()
            let r1 = -w0 * (zeta - root), r2 = -w0 * (zeta + root)
            return 1 + (r2 * exp(r1 * t) - r1 * exp(r2 * t)) / (r1 - r2)
        }
    }

    /// How long until it settles, as the prototype measures it (capped at 2.5s).
    var duration: Double {
        var x = 0.0, v = 0.0, t = 0.0, still = 0
        let dt = 1.0 / 240
        while t < 2.5 {
            v += (-k * (x - 1) - c * v) * dt
            x += v * dt
            t += dt
            if abs(x - 1) < 0.002 && abs(v) < 0.02 {
                still += 1
                if still > 10 { break }
            } else {
                still = 0
            }
        }
        return t
    }
}

/// Progress of one segment of a timeline: 0 before `delay`, 1 after `delay + duration`.
func seg(_ t: Double, _ delay: Double, _ duration: Double, _ ease: Ease = .linear) -> Double {
    guard duration > 0 else { return t >= delay ? 1 : 0 }
    return ease(min(max((t - delay) / duration, 0), 1))
}

/// Piecewise-linear keyframes at `progress` (offsets spread evenly unless given), like WAAPI.
func kf(_ progress: Double, _ values: [Double], _ offsets: [Double]? = nil) -> Double {
    guard let first = values.first else { return 0 }
    guard values.count > 1 else { return first }
    let stops = offsets ?? values.indices.map { Double($0) / Double(values.count - 1) }
    if progress <= stops[0] { return first }
    for i in 1..<values.count where progress <= stops[i] {
        let span = stops[i] - stops[i - 1]
        let local = span > 0 ? (progress - stops[i - 1]) / span : 1
        return values[i - 1] + (values[i] - values[i - 1]) * local
    }
    return values[values.count - 1]
}

extension Animation {
    /// `cubic-bezier(a, b, c, d)` over `duration` seconds (overshooting control points are fine).
    static func curve(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ duration: Double) -> Animation {
        .timingCurve(a, b, c, d, duration: duration)
    }

    /// `spring(k, c)`: a mass-1 spring.
    static func spring(k: Double, c: Double) -> Animation {
        .interpolatingSpring(mass: 1, stiffness: k, damping: c)
    }

    /// With Reduce Motion: a 0.2s ease-out instead.
    @MainActor var rm: Animation { Motion.reduced ? .easeOut(duration: 0.2) : self }
}

enum Motion {
    @MainActor static var reduced: Bool { UIAccessibility.isReduceMotionEnabled }

    /// Pages and Capture flood out of what you tapped.
    static let flood = Animation.curve(0.7, 0, 0.2, 1, 0.62)
    /// The tab pill and slot widths.
    static let tab = Animation.curve(0.3, 1.25, 0.45, 1, 0.5)
    /// Segment underlines, pills and the chip pill.
    static let indicator = Animation.curve(0.3, 1.3, 0.5, 1, 0.42)
    /// The bar takes the page colour.
    static let barFade = Animation.curve(0.4, 0, 0.2, 1, 0.45)
    /// Lists sliding in the direction of travel.
    static let slide = Animation.curve(0.2, 0.85, 0.25, 1, 0.38)
    /// A row folding away.
    static let fold = Animation.curve(0.4, 0, 0.2, 1, 0.36)
    /// A hero card leaving to the right.
    static let leave = Animation.curve(0.5, 0, 0.75, 0, 0.3)
    /// A new hero rising in.
    static let arrive = Animation.curve(0.2, 0.85, 0.25, 1, 0.46)
    /// Snap with a small overshoot.
    static let snap = Animation.curve(0.3, 1.5, 0.5, 1, 0.42)
    /// The Today sheet dropping away.
    static let drop = Animation.curve(0.6, 0, 0.25, 1, 0.6)
    /// The sheet rising over the poster to the top bar, or dropping back (the web's .sheet.up).
    static let sheetLift = Animation.curve(0.3, 1.15, 0.4, 1, 0.5)

    /// Runs `work` on the main actor after `seconds` (at once with Reduce Motion, unless `always`).
    @MainActor static func after(_ seconds: Double, always: Bool = false, _ work: @escaping @MainActor () -> Void) {
        let wait = reduced && !always ? 0 : seconds
        Task { @MainActor in
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            work()
        }
    }
}

// MARK: - Entry: posters rise and drawings draw when a screen appears

extension EnvironmentValues {
    /// Bumped each time the screen comes into view: posters rise, drawings draw, numbers count.
    @Entry var entry: Int = 0
    /// Delay before the rise starts (pages wait for their flood).
    @Entry var entryDelay: Double = 0
}

private struct RiseValue {
    var opacity: Double = 1
    var y: CGFloat = 0
}

private struct RiseModifier: ViewModifier {
    @Environment(\.entry) private var entry
    @Environment(\.entryDelay) private var base
    @Environment(\.accessibilityReduceMotion) private var reduce
    let index: Int
    let sheet: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduce {
            content
        } else {
            content.keyframeAnimator(initialValue: RiseValue(), trigger: entry) { view, v in
                view.opacity(v.opacity).offset(y: v.y)
            } keyframes: { _ in
                let delay = max(base + Double(index) * 0.05, 0.001)
                let curve: UnitCurve = sheet
                    ? .bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.85), endControlPoint: UnitPoint(x: 0.25, y: 1))
                    : .bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1))
                let duration = sheet ? 0.52 : 0.48
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(sheet ? 0.4 : 0)
                    LinearKeyframe(sheet ? 0.4 : 0, duration: delay)
                    LinearKeyframe(1, duration: duration, timingCurve: curve)
                }
                KeyframeTrack(\.y) {
                    MoveKeyframe(sheet ? 46 : 16)
                    LinearKeyframe(sheet ? 46 : 16, duration: delay)
                    LinearKeyframe(0, duration: duration, timingCurve: curve)
                }
            }
        }
    }
}

extension View {
    /// A poster element rising in (opacity 0 → 1, y +16 → 0, 50ms stagger).
    func rise(_ index: Int = 0) -> some View { modifier(RiseModifier(index: index, sheet: false)) }
    /// The sheet gliding up (y +46 → 0, opacity 0.4 → 1).
    func riseSheet() -> some View { modifier(RiseModifier(index: 0, sheet: true)) }
}

// MARK: - A clock for timed moments

private struct ClockValue {
    var t: Double
}

/// What a `Clock` reads at rest: long after every moment has finished, so content shows its settled state.
let clockRest: Double = 1_000

/// Plays a clock from 0 to `duration` seconds each time `trigger` changes. At rest it reads `clockRest`.
struct Clock<Content: View>: View {
    let trigger: Int
    let duration: Double
    let content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduce

    init(trigger: Int, duration: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.trigger = trigger
        self.duration = duration
        self.content = content
    }

    var body: some View {
        if reduce {
            content(clockRest)
        } else {
            Color.clear.keyframeAnimator(initialValue: ClockValue(t: clockRest), trigger: trigger) { _, v in
                content(v.t)
            } keyframes: { _ in
                KeyframeTrack(\.t) {
                    MoveKeyframe(0)
                    LinearKeyframe(duration, duration: duration)
                }
            }
        }
    }
}

// MARK: - Pop and press

private struct PopValue {
    var scale: CGFloat = 1
}

extension View {
    /// Scale 1 → 1.18 → 1 over 460ms each time `trigger` changes.
    func pop(_ trigger: Int, to peak: CGFloat = 1.18) -> some View {
        keyframeAnimator(initialValue: PopValue(), trigger: trigger) { view, v in
            view.scaleEffect(v.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(peak, duration: 0.2, timingCurve: .easeOut)
                SpringKeyframe(1, duration: 0.26, spring: .bouncy)
            }
        }
    }
}

/// Buttons scale to 0.95 (tiles 0.97) while pressed.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
    static var pressTile: PressStyle { PressStyle(scale: 0.97) }
}
