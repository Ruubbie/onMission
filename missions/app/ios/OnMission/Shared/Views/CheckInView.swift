import SwiftUI
import SwiftData

/// After a call (handoff §6): slide how it went. The whole screen goes from plum through marigold to tomato,
/// the sun rises over the hills and the big word rolls between NOT NOW, THINKING and YES!
struct CheckInView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    @Environment(\.dynamicTypeSize) private var dts
    @Environment(\.accessibilityReduceMotion) private var reduce
    let request: CheckInRequest

    @State private var t: Double = 0.5
    @State private var word = 1
    @State private var up = true
    @State private var dragging = false
    @State private var snapping: Task<Void, Never>?
    @State private var addingNote = false
    @State private var note = ""
    @State private var saved = 0
    @FocusState private var noteFocused: Bool

    private struct Stop {
        let word: String
        let next: String
        let model: PartnerStage
    }

    private let stops = [
        Stop(word: "Not now", next: "That's okay. I'll suggest a catch-up in spring.", model: .declined),
        Stop(word: "Thinking", next: "I'll remind you to follow up in 2 weeks.", model: .thinking),
        Stop(word: "Yes!", next: "Committed! Next up: a thank-you and the amount.", model: .committed),
    ]

    private var background: Color {
        t <= 0.5 ? Color.mix(0x4B3B52, 0xE8A13A, t * 2) : Color.mix(0xE8A13A, 0xD2462B, (t - 0.5) * 2)
    }

    private var ink: Color { (t < 0.27 || t >= 0.74) ? Palette.cream : Palette.ink }

    private var name: String {
        request.partner.firstName.isEmpty ? request.partner.displayTitle : request.partner.firstName
    }

    var body: some View {
        let k = chrome.posterScale(dts)
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                PosterCanvas(height: 600, scale: k) {
                    Text("how did it go with \(name)?")
                        .type(.hand(36))
                        .frame(width: 390)
                        .multilineTextAlignment(.center)
                        .offset(y: 112 - 104)
                    sky.offset(x: 45, y: 160 - 104)
                    rollingWord.offset(y: 410 - 104)
                    Text(stops[word].next)
                        .type(TypeStyle(size: 15.5, wght: 600, relativeTo: nil))
                        .opacity(0.85)
                        .multilineTextAlignment(.center)
                        .frame(width: 330)
                        .id("next-\(word)")
                        .transition(.opacity)
                        .offset(x: 30, y: 522 - 104)
                    slider.offset(x: 44, y: 586 - 104)
                    labels.offset(x: 14, y: 650 - 104)
                }
                if addingNote {
                    TextField("A note about the call", text: $note, axis: .vertical)
                        .type(.bodyBold)
                        .lineLimit(2...5)
                        .focused($noteFocused)
                        .padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ink.opacity(0.5), lineWidth: 1.6))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            actions
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .onChange(of: t) { _, new in
            router.checkInT = new
            let idx = Int((new * 2).rounded())
            if idx != word {
                up = idx > word
                withAnimation(.curve(0.2, 1.3, 0.4, 1, 0.42).rm) { word = idx }
            }
        }
        .onAppear {
            router.checkInT = 0.5
            guard !reduce else { return }
            // A small nudge so you see it moves.
            Motion.after(0.65) {
                snap(to: 0.62) { snap(to: 0.5) }
            }
        }
        .sensoryFeedback(.selection, trigger: word)
        .sensoryFeedback(.success, trigger: saved)
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 10) {
            Text("After the call").type(.kicker).frame(maxWidth: .infinity, alignment: .leading)
            RoundButton(icon: .x, label: "Close") { close() }
        }
        .padding(.leading, Metrics.gutter)
        .padding(.trailing, 18)
        .frame(height: Metrics.topBar)
        .padding(.top, chrome.top - 3)
    }

    /// Moon and stars at night, a sun that rises with its rays, and the hills.
    private var sky: some View {
        let cy = 206 - t * 124
        let len = 6 + t * 18
        let rayOpacity = min(max((t - 0.3) / 0.45, 0), 1)
        let style = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                SVGShape(d: "M236 34 A 22 22 0 1 0 258 66 A 17 17 0 1 1 236 34 Z").fill(background)
                SVGShape(d: "M236 34 A 22 22 0 1 0 258 66 A 17 17 0 1 1 236 34 Z").stroke(ink, style: style)
                SVGShape(d: "M62 44 v12 M56 50 h12 M104 22 v9 M99.5 26.5 h9 M196 92 v9 M191.5 96.5 h9").stroke(ink, style: style)
            }
            .opacity(max(0, 1 - t * 2.4))
            ZStack(alignment: .topLeading) {
                Path { p in
                    for i in 0..<12 {
                        let a = Double(i) * 30 * .pi / 180
                        let r0 = 48.0
                        p.move(to: CGPoint(x: 150 + cos(a) * r0, y: cy + sin(a) * r0))
                        p.addLine(to: CGPoint(x: 150 + cos(a) * (r0 + len), y: cy + sin(a) * (r0 + len)))
                    }
                }
                .stroke(ink, style: style)
                .opacity(rayOpacity)
                Circle().fill(background).frame(width: 76, height: 76).position(x: 150, y: cy)
                Circle().stroke(ink, lineWidth: 2.6).frame(width: 76, height: 76).position(x: 150, y: cy)
            }
            .frame(width: 300, height: 190, alignment: .topLeading)
            .clipped()
            SVGShape(d: "M-4 186 C 40 150, 84 140, 128 160 C 166 134, 222 128, 304 168 L304 234 L-4 234 Z").fill(background)
            SVGShape(d: "M-4 186 C 40 150, 84 140, 128 160 C 166 134, 222 128, 304 168").stroke(ink, style: style)
            SVGShape(d: "M60 230 C 90 206, 120 196, 150 194 C 184 192, 214 200, 248 230").stroke(ink, style: style)
            SVGShape(d: "M108 172 L112 168 L118 172 L124 167 L130 172").stroke(ink, style: style)
        }
        .frame(width: 300, height: 230, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private var rollingWord: some View {
        ZStack {
            Lines(stops[word].word, .disp(90))
                .id(word)
                .transition(.asymmetric(insertion: .offset(y: up ? 70 : -70).combined(with: .opacity),
                                        removal: .offset(y: up ? -70 : 70).combined(with: .opacity)))
        }
        .frame(width: 390, height: 100)
        .clipped()
        .accessibilityHidden(true)
    }

    private var slider: some View {
        let width: CGFloat = 302
        return ZStack(alignment: .topLeading) {
            Capsule().fill(ink.opacity(0.5)).frame(width: width, height: 2.4).offset(y: 28.8)
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(background)
                    .overlay(Circle().strokeBorder(ink, lineWidth: 2.4))
                    .frame(width: 12, height: 12)
                    .offset(x: width * CGFloat(i) / 2 - 6, y: 24)
            }
            AnimatedIcon(.sun, size: 26, trigger: word)
                .foregroundStyle(background)
                .frame(width: 54, height: 54)
                .background(Circle().fill(ink))
                .scaleEffect(dragging ? 1.1 : 1)
                .animation(.easeOut(duration: 0.2), value: dragging)
                .offset(x: width * t - 27, y: 3)
        }
        .frame(width: width, height: 60, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    snapping?.cancel()
                    dragging = true
                    t = min(max(v.location.x / width, 0), 1)
                }
                .onEnded { _ in
                    dragging = false
                    snap(to: (t * 2).rounded() / 2)
                }
        )
        .accessibilityElement()
        .accessibilityLabel("How it went")
        .accessibilityValue(stops[word].word)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: snap(to: min(1, (t * 2).rounded() / 2 + 0.5))
            case .decrement: snap(to: max(0, (t * 2).rounded() / 2 - 0.5))
            @unknown default: break
            }
        }
    }

    private var labels: some View {
        HStack {
            ForEach(0..<3, id: \.self) { i in
                Button { snap(to: Double(i) / 2) } label: {
                    Text(stops[i].word.uppercased())
                        .type(TypeStyle(size: 13, wght: 800, tracking: 0.08, relativeTo: nil))
                        .opacity(i == word ? 1 : 0.55)
                        .frame(width: 90, height: 44, alignment: i == 0 ? .leading : (i == 1 ? .center : .trailing))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < 2 { Spacer(minLength: 0) }
            }
        }
        .frame(width: 362)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { addingNote.toggle() }
                if addingNote { noteFocused = true }
            } label: {
                Text(addingNote ? "Hide note" : "Add note")
                    .type(TypeStyle(size: 16.5, wght: 800, relativeTo: .body))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .overlay(Capsule().strokeBorder(ink, lineWidth: 1.8))
                    .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .layoutPriority(1)
            Button { save() } label: {
                HStack(spacing: 9) {
                    Text("Save").type(TypeStyle(size: 16.5, wght: 800, relativeTo: .body))
                    AnimatedIcon(.arrow, size: 19, trigger: saved)
                }
                .foregroundStyle(background)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Capsule().fill(ink))
                .contentShape(Capsule())
            }
            .buttonStyle(.press)
            .layoutPriority(1.35)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, max(chrome.bottomSafe, 16) + 6)
        .padding(.top, 8)
    }

    // MARK: Behaviour

    /// Snaps to a stop with a small overshoot (420ms), stepping `t` so everything follows.
    private func snap(to target: Double, then: (() -> Void)? = nil) {
        snapping?.cancel()
        let from = t
        guard !reduce else {
            t = target
            then?()
            return
        }
        snapping = Task { @MainActor in
            let steps = 26
            for step in 1...steps {
                if Task.isCancelled { return }
                let x = Double(step) / Double(steps)
                let k = x < 1 ? 1 - pow(1 - x, 3) * cos(x * 4) : 1
                t = from + (target - from) * min(1.04, k)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            t = target
            then?()
        }
    }

    private func close() {
        router.checkInT = 0.5
        withAnimation(.curve(0.2, 0.9, 0.2, 1, 0.55).rm) { router.checkIn = nil }
    }

    private func save() {
        saved += 1
        let stop = stops[word]
        let p = request.partner
        let today = Calendar.current.startOfDay(for: .now)
        p.lastContact = today
        switch stop.model {
        case .thinking:
            p.nextFollowUp = Calendar.current.date(byAdding: .day, value: 14, to: today)
            p.nextStep = "Call to follow up"
            p.move(to: .thinking, ctx)
        case .declined:
            p.move(to: .declined, ctx)
            p.nextStep = "Catch up in spring"
            p.nextFollowUp = nextSpring(after: today)
        default:
            p.move(to: .committed, ctx)
        }
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let stamp = today.formatted(date: .abbreviated, time: .omitted)
            p.notes = p.notes.isEmpty ? "\(stamp): \(text)" : "\(p.notes)\n\(stamp): \(text)"
        }
        if let task = request.task, !task.isDone {
            task.setDone(true)
            Automations.taskDone(task, ctx)
        }
        close()
        let who = p.displayTitle
        Motion.after(0.38) { router.showToast("\(who) · \(stop.model.title)") }
    }

    private func nextSpring(after d: Date) -> Date? {
        let cal = Calendar.current
        var c = cal.dateComponents([.year], from: d)
        c.month = 3
        c.day = 1
        guard let thisYear = cal.date(from: c) else { return nil }
        return thisYear > d ? thisYear : cal.date(byAdding: .year, value: 1, to: thisYear)
    }
}
