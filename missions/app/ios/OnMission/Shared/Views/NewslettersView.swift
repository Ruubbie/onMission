import SwiftUI
import SwiftData

extension Newsletter {
    func set(_ s: NewsletterStatus) {
        statusValue = s
        if s == .sent && sentAt == nil { sentAt = .now }
        if s != .sent { sentAt = nil }
    }

    var words: Int { body.split(whereSeparator: \.isWhitespace).count }
}

// MARK: - Newsletters (handoff §7): the next letter, and Mark sent sends it flying

struct NewslettersPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Newsletter.number, order: .reverse) private var letters: [Newsletter]
    @Query private var partners: [Partner]
    @State private var send = 0
    @State private var away = false
    @State private var sending = false
    @State private var sentPlay = 0

    var body: some View {
        let draft = letters.filter { $0.statusValue != .sent }.min { $0.number < $1.number }
        let sent = letters.filter { $0.statusValue == .sent }.sorted { ($0.sentAt ?? .distantPast) > ($1.sentAt ?? .distantPast) }
        let due = draft?.plannedDate ?? nextMonth
        let month = due.formatted(.dateTime.month(.abbreviated)).uppercased()
        Screen(posterHeight: 306) {
            Hand("Next letter").rise(0).at(24, 106)
            Lines(month, .disp(140), lineHeight: 0.8)
                .id(month)
                .transition(.asymmetric(insertion: .offset(y: 30).combined(with: .opacity), removal: .offset(y: -30).combined(with: .opacity)))
                .rise(1)
                .at(18, 134)
            CapLine("\(draft?.plannedDate == nil ? "No date yet" : "Due \(due.formatted(.dateTime.day().month(.wide)))")\nto \(partners.count) people")
                .id(month)
                .transition(.opacity)
                .rise(2)
                .at(24, 276)
            EnvelopeFlight(send: send)
                .opacity(away ? 0 : 1)
                .at(0, 0)
        } sheet: {
            SheetScroll {
                if let draft {
                    SectionHeader(draft.statusValue == .idea ? "Up next" : "Draft")
                    HeroCard(title: draft.displayTitle, subtitle: started(draft)) {
                        ActionButton(title: "Mark sent", icon: .mail) { markSent(draft) }
                        ActionButton(title: "Open draft", style: .outlined) { router.push(.record(.newsletter(draft))) }
                    }
                    .id(draft.id)
                    .transition(.asymmetric(insertion: .offset(y: 22).combined(with: .opacity), removal: .scale(scale: 0.96).combined(with: .opacity)))
                } else {
                    SectionHeader("Up next")
                    HeroCard(title: "\(nextMonth.formatted(.dateTime.month(.wide))) letter",
                             subtitle: sent.first.map { "Not started yet. Your last one went out \(relativeDate($0.sentAt ?? .now))." } ?? "Not started yet.") {
                        ActionButton(title: "Start writing", icon: .pen) { newLetter() }
                    }
                    .transition(.asymmetric(insertion: .offset(y: 22).combined(with: .opacity), removal: .opacity))
                }
                SectionHeader("Sent", count: sent.count).padding(.top, 22)
                ForEach(Array(sent.enumerated()), id: \.element.id) { index, n in
                    Button { router.push(.record(.newsletter(n))) } label: {
                        Row(rule: index < sent.count - 1) {
                            RowText(title: n.displayTitle,
                                    subtitle: [n.number > 0 ? "#\(n.number)" : nil, n.sentAt.map { $0.formatted(.dateTime.month(.wide)) }]
                                        .compactMap { $0 }.joined(separator: " · "))
                            WhenText(text: whenText(n.sentAt))
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(insertion: .offset(y: -18).combined(with: .opacity), removal: .opacity))
                }
                if sent.isEmpty {
                    EmptyRow(title: "None sent yet", message: "Your letters show up here once they're out.")
                }
                if draft != nil {
                    MoreLink(title: "Start another letter") { newLetter() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: sentPlay)
    }

    private var nextMonth: Date {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return cal.date(byAdding: .month, value: 1, to: start) ?? .now
    }

    private func started(_ n: Newsletter) -> String {
        let words = n.words
        return "Started \(relativeDate(n.createdAt)) · \(words) word\(words == 1 ? "" : "s")"
    }

    /// The letter slides into the envelope, the flap closes, the envelope flies off along the dotted route.
    private func markSent(_ n: Newsletter) {
        guard !sending else { return }
        sending = true
        send += 1
        Motion.after(1.45) { away = true }
        Motion.after(1.55) {
            withAnimation(Motion.arrive.rm) { n.set(.sent) }
            sentPlay += 1
            router.showToast("\(n.displayTitle) marked as sent")
            Motion.after(0.5, always: true) {
                withAnimation(.easeOut(duration: 0.4)) { away = false }
                sending = false
            }
        }
    }

    private func newLetter() {
        let n = Newsletter()
        n.number = (letters.map(\.number).max() ?? 0) + 1
        n.title = "Newsletter \(n.number)"
        n.statusValue = .draft
        n.plannedDate = nextMonth
        n.body = "Opening (what happened, one story):\n\n\nWhat's next:\n\n\nPrayer points:\n- \n\nThank you:\n"
        ctx.insert(n)
        router.push(.record(.newsletter(n)))
    }
}

/// The envelope at the end of a dotted route, and its trip along it.
private struct EnvelopeFlight: View {
    let send: Int
    private static let route = "M318 270 C 350 250, 352 204, 372 178 S 420 132, 460 120"

    var body: some View {
        let path = SVG.path(Self.route)
        ZStack(alignment: .topLeading) {
            LineArt(drawing: Drawing(width: 390, height: 396, paths: [.dots(Self.route)]))
            Clock(trigger: send, duration: 1.52) { t in
                let slide = seg(t, 0, 0.26, .outCubic)
                let flap = seg(t, 0.26, 0.3, .outCubic)
                let flying = t > 0.56 && t < 1.51
                let k: Double = {
                    guard flying else { return 0 }
                    let x = (t - 0.56) / 0.95
                    return x * x * (3 - 2 * x)
                }()
                let spot = path.point(at: max(k, 0.0005))
                let at = flying ? spot.point : CGPoint(x: 318, y: 270)
                Envelope(slide: t < 1.51 ? slide : 0, flap: t < 1.51 ? flap : 0)
                    .scaleEffect(1 - 0.45 * k)
                    .rotationEffect(.degrees(flying ? spot.angle * k : 0))
                    .position(x: at.x, y: at.y - 16)
            }
            .frame(width: 390, height: 396, alignment: .topLeading)
        }
        .frame(width: 390, height: 396, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The envelope (100 × 100, its middle on the route): a paper letter that slides in, a flap that closes.
private struct Envelope: View {
    let slide: Double
    let flap: Double

    var body: some View {
        let line = StrokeStyle(lineWidth: Metrics.line, lineCap: .round, lineJoin: .round)
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                SVGShape(d: "M16 16 L84 16 L84 54 L16 54 Z").fill(Palette.paper)
                SVGShape(d: "M16 16 L84 16 L84 54 L16 54 Z").stroke(Palette.ink, style: line)
            }
            .offset(y: 34 * slide)
            SVGShape(d: "M4 36 L96 36 L96 96 L4 96 Z").fill(Palette.flood)
            SVGShape(d: "M4 36 L96 36 L96 96 L4 96 Z").stroke(Palette.ink, style: line)
            SVGShape(d: "M4 96 L40 68 M96 96 L60 68").stroke(Palette.ink, style: line)
            Path { p in
                p.move(to: CGPoint(x: 4, y: 36))
                p.addLine(to: CGPoint(x: 50, y: 4 + 68 * flap))
                p.addLine(to: CGPoint(x: 96, y: 36))
            }
            .stroke(Palette.ink, style: line)
            SVGShape(d: "M50 84 C 41 78, 39 72, 43 68 C 46 65, 49 66, 50 69 C 51 66, 54 65, 57 68 C 61 72, 59 78, 50 84 Z")
                .fill(Palette.coral)
        }
        .frame(width: 100, height: 100, alignment: .topLeading)
    }
}

// MARK: - One letter

struct NewsletterDetail: View {
    @Bindable var letter: Newsletter

    var body: some View {
        let cap: String = {
            if let sent = letter.sentAt { return "Sent \(longDate(sent))" }
            if let planned = letter.plannedDate { return "Planned for \(longDate(planned))" }
            return "\(letter.words) words"
        }()
        DetailPage(aside: letter.number > 0 ? "Letter #\(letter.number)" : "A letter", title: letter.displayTitle, cap: cap) {
            FormBlock("Letter") {
                TextRow("Title", text: $letter.title)
                SelectRow("Status", selection: Binding(get: { letter.statusValue }, set: { letter.set($0) })) {
                    ForEach(NewsletterStatus.allCases) { Text($0.title).tag($0) }
                }
                StepperRow(title: "Number", value: $letter.number, range: 0...999)
                OptionalDateRow(title: "Planned for", date: $letter.plannedDate)
            }
            FormBlock("Text", footer: "\(letter.words) words") {
                TextField("", text: $letter.body, prompt: Text("Write…").foregroundStyle(Palette.inkFaint), axis: .vertical)
                    .type(.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(12...)
                    .padding(.vertical, 12)
            }
            ShareLink(item: "\(letter.title)\n\n\(letter.body)") {
                FieldRow {
                    AnimatedIcon(.share, size: 20).foregroundStyle(Palette.ink)
                    Text("Share the text").type(.bodyBold).foregroundStyle(Palette.ink)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            FormBlock("More") {
                TextRow("Web version link", text: $letter.webURL, keyboard: .URL, plain: true)
                if let url = URL(string: letter.webURL), !letter.webURL.isEmpty, url.scheme != nil {
                    Link(destination: url) {
                        FieldRow {
                            AnimatedIcon(.globe, size: 20).foregroundStyle(Palette.ink)
                            Text("Open web version").type(.bodyBold).foregroundStyle(Palette.ink)
                        }
                    }
                }
                TextRow("Notes (who to send to, photos to use…)", text: $letter.notes, vertical: true, lines: 2...8)
            }
            LinksBlock(record: .newsletter(letter))
            DeleteButton(item: letter)
        }
        .captureContext(.task, linkTo: .newsletter(letter))
    }
}
