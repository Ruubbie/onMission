import SwiftUI
import SwiftData

// MARK: - Thanks (journal notes marked #thanks, so the sync contract stays the same)

extension Note {
    static let thanksMarker = "#thanks"
    var isThanks: Bool { kindValue == .journal && body.hasPrefix(Note.thanksMarker) }

    @discardableResult
    static func addThanks(_ text: String, _ ctx: ModelContext) -> Note {
        let n = Note()
        n.kindValue = .journal
        n.title = text
        n.body = thanksMarker
        n.areaValue = .personal
        ctx.insert(n)
        return n
    }
}

extension Art {
    /// Prayer: a candle on its dish. The flame and its glow are drawn by the screen.
    static let candle = Drawing(width: 120, height: 190, paths: [
        .line("M60 74 L60 64"),
        .flood("M38 80 L38 160 L82 160 L82 80"),
        .line("M38 80 A22 6 0 0 0 82 80 A22 6 0 0 0 38 80"),
        .line("M48 87 C 46 95, 48 103, 52 107"),
        .line("M14 160 L106 160"),
        .line("M22 160 C 24 175, 96 175, 98 160"),
    ])
}

// MARK: - Prayer (handoff §5): one prayer, a candle with the traveller kneeling beside it, I prayed

struct PrayerView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Note.createdAt) private var notes: [Note]

    @State private var pi = 0
    @State private var praying = false
    @State private var lit = false
    @State private var light = 0
    @State private var prayedPlay = 0
    @State private var amen = false
    @State private var cardX: CGFloat = 0
    @State private var cardTilt: Double = 0
    @State private var cardOpacity: Double = 1
    @State private var dragging = false
    @State private var linkPlay = 0

    private var open: [Note] { notes.filter { $0.kindValue == .prayer && $0.answeredAt == nil } }

    var body: some View {
        let list = open
        let i = list.isEmpty ? 0 : min(pi, list.count - 1)
        Screen(posterHeight: 640) {
            Hand("pray for", size: 34).rise(0).at(24, 116)
            journalLink.rise(0).at(24, 120)
            if list.isEmpty {
                Lines("Nothing\nopen.", .disp(96)).rise(1).at(20, 168)
                Hand("Add a prayer with the +", size: 29, tilt: -3).rise(2).at(26, 340)
            } else {
                card(list[i], count: list.count).rise(1).at(24, 160)
            }
            candle.at(135, 392)
            Hand("Amen.", size: 46, tilt: -9)
                .scaleEffect(amen ? 1 : 0.6)
                .opacity(amen ? 1 : 0)
                .accessibilityHidden(!amen)
                .at(246, 430)
            if !list.isEmpty {
                buttons(list[i], count: list.count).rise(2).at(0, 604)
            }
            if list.count > 1 {
                pager(count: list.count, current: i).at(0, 694)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: light)
        .captureContext(.prayer)
    }

    // MARK: Poster parts

    private var journalLink: some View {
        Button {
            linkPlay += 1
            router.push(.prayerJournal)
        } label: {
            HStack(spacing: 6) {
                Text("Answered & thanks").type(.buttonSmall)
                AnimatedIcon(.arrow, size: 16, trigger: linkPlay)
            }
            .foregroundStyle(Palette.ink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .frame(width: 342, alignment: .trailing)
    }

    private func card(_ p: Note, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Lines(wrapLines(p.displayTitle, .prayer, width: 342, maxLines: 5), .prayer, lineHeight: 1.06, minScale: 0.6)
            HStack(spacing: 0) {
                Text("Added \(relativeDate(p.createdAt)) · prayed ")
                Text("\(p.prayedCount)").contentTransition(.numericText(value: Double(p.prayedCount)))
                Text("×")
            }
            .type(TypeStyle(size: 14.5, wght: 600, relativeTo: nil))
            .opacity(0.82)
            .lineLimit(1)
            .padding(.top, 12)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 342, alignment: .topLeading)
        .frame(minHeight: 210, alignment: .topLeading)
        .contentShape(Rectangle())
        .offset(x: cardX)
        .rotationEffect(.degrees(cardTilt))
        .opacity(cardOpacity)
        .gesture(swipe(count: count))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(p.displayTitle). Prayed \(p.prayedCount) times.")
        .accessibilityHint(count > 1 ? "Swipe up or down for the next prayer." : "")
        .accessibilityAdjustableAction { direction in
            guard count > 1 else { return }
            next(direction == .increment ? 1 : -1)
        }
    }

    private func buttons(_ p: Note, count: Int) -> some View {
        HStack(spacing: 10) {
            Button { answered(p) } label: { Text("Answered") }
                .buttonStyle(.outlined)
            Button { prayed(p) } label: {
                ButtonLabel(title: praying ? "Prayed" : "I prayed", icon: .flame, trigger: prayedPlay)
                    .frame(minWidth: 110)
            }
            .buttonStyle(.filled)
            .pop(prayedPlay, to: 1.06)
        }
        .frame(width: 390)
    }

    @ViewBuilder
    private func pager(count: Int, current: Int) -> some View {
        Group {
            if count <= 12 {
                HStack(spacing: 7) {
                    ForEach(0..<count, id: \.self) { j in
                        Capsule()
                            .fill(Palette.ink)
                            .frame(width: j == current ? 20 : 7, height: 7)
                            .opacity(j == current ? 1 : 0.4)
                    }
                }
                .animation(.easeOut(duration: 0.3), value: current)
            } else {
                Text("\(current + 1) of \(count)")
                    .type(.small)
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
            }
        }
        .frame(width: 390)
        .accessibilityHidden(true)
    }

    // MARK: The candle

    private var candle: some View {
        Clock(trigger: light, duration: 2.3) { t in
            ZStack(alignment: .topLeading) {
                let g = seg(t, 0.26, 0.52, Ease(0.3, 1.5, 0.5, 1))
                SVGShape(d: "M60 14 V5 M36 26 L30 21 M84 26 L90 21 M30 50 H21 M90 50 H99")
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineCap: .round))
                    .frame(width: 120, height: 190, alignment: .topLeading)
                    .scaleEffect(0.6 + 0.4 * g, anchor: UnitPoint(x: 0.5, y: 46.0 / 190))
                    .opacity(min(g, 1))
                    .opacity(lit ? 1 : 0)
                LineArt(drawing: Art.candle)
                let f = flame(t)
                FlameShape()
                    .scaleEffect(x: f.sx, y: f.sy, anchor: UnitPoint(x: 0.5, y: 70.0 / 190))
                    .rotationEffect(.degrees(f.rot), anchor: UnitPoint(x: 0.5, y: 70.0 / 190))
                    .scaleEffect(lit ? 1 : 0, anchor: UnitPoint(x: 0.5, y: 70.0 / 190))
            }
            .frame(width: 120, height: 190, alignment: .topLeading)
            .offset(y: t < 0.3 ? kf(t / 0.3, [0, 3, 0]) : 0)
        }
        .accessibilityElement()
        .accessibilityLabel(lit ? "A lit candle" : "A candle")
    }

    /// The flame catches (0 → 1.25/1.3 → 0.94 → 1 over 700ms), then flickers twice (760ms each).
    private func flame(_ t: Double) -> (sx: Double, sy: Double, rot: Double) {
        if t < 0.7 {
            let p = Ease(0.3, 1.3, 0.5, 1)(t / 0.7)
            let stops = [0, 0.55, 0.8, 1.0]
            return (kf(p, [0, 1.25, 0.94, 1], stops), kf(p, [0, 1.3, 0.94, 1], stops), 0)
        }
        let ft = t - 0.7
        guard ft < 1.52 else { return (1, 1, 0) }
        let local = Ease.easeInOut(ft.truncatingRemainder(dividingBy: 0.76) / 0.76)
        return (kf(local, [1, 1.05, 0.97, 1]), kf(local, [1, 0.96, 1.05, 1]), kf(local, [0, -3, 2.5, 0]))
    }

    // MARK: Moments

    private func prayed(_ p: Note) {
        guard !praying else { return }
        praying = true
        prayedPlay += 1
        lit = true
        light += 1
        withAnimation(.snappy) { p.prayedCount += 1 }
        p.lastPrayedAt = .now
        Motion.after(0.45) {
            withAnimation(.curve(0.3, 1.6, 0.5, 1, 0.45).rm) { amen = true }
        }
        Motion.after(2.1, always: true) {
            next(1)
            Motion.after(0.75, always: true) { praying = false }
        }
    }

    private func answered(_ p: Note) {
        guard !praying else { return }
        praying = true
        let origin = TouchPoint.last ?? CGPoint(x: 140, y: 700)
        TouchPoint.last = nil
        router.openAnswered(p.displayTitle, from: origin)
        Motion.after(2.5, always: true) {
            resetCandle()
            p.answeredAt = .now
            router.closeAnswered()
            praying = false
        }
    }

    private func swipe(count: Int) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                guard !praying else { return }
                if !dragging {
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    dragging = true
                }
                cardX = v.translation.width
                cardTilt = cardX / 40
            }
            .onEnded { v in
                guard dragging else { return }
                dragging = false
                let dx = v.translation.width
                if abs(dx) > 70 && count > 1 {
                    next(dx < 0 ? 1 : -1)
                } else {
                    withAnimation(.curve(0.3, 1.5, 0.5, 1, 0.42).rm) {
                        cardX = 0
                        cardTilt = 0
                    }
                }
            }
    }

    /// The card slides out (with a little tilt), the next one slides in from the other side.
    private func next(_ dir: Int) {
        resetCandle()
        withAnimation(.curve(0.5, 0, 0.75, 0, 0.26).rm) {
            cardX = CGFloat(-dir) * 70
            cardTilt = Double(-dir) * 3
            cardOpacity = 0
        } completion: {
            let n = max(open.count, 1)
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                pi = ((min(pi, n - 1) + dir) % n + n) % n
                cardX = CGFloat(dir) * 70
                cardTilt = 0
            }
            Task { @MainActor in
                withAnimation(.curve(0.2, 0.85, 0.25, 1, 0.46).rm) {
                    cardX = 0
                    cardOpacity = 1
                }
            }
        }
    }

    private func resetCandle() {
        withAnimation(.easeOut(duration: 0.2)) { amen = false }
        guard lit else { return }
        withAnimation(.easeIn(duration: 0.26)) { lit = false }
    }
}

/// The flame: coral with an ink outline and an ochre heart, as on the web.
private struct FlameShape: View {
    private static let outer = "M60 24 C 68 38, 74 44, 74 56 A 14 14 0 0 1 46 56 C 46 44, 52 38, 60 24 Z"
    private static let inner = "M60 46 C 63 51, 66 54, 66 59 A 6 6 0 0 1 54 59 C 54 54, 57 51, 60 46 Z"

    var body: some View {
        ZStack(alignment: .topLeading) {
            SVGShape(d: Self.outer).fill(Palette.coral)
            SVGShape(d: Self.outer).stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineJoin: .round))
            SVGShape(d: Self.inner).stroke(Palette.ochre, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }
        .frame(width: 120, height: 190, alignment: .topLeading)
    }
}

// MARK: - Prayer & thanks (a page from the Prayer tab)

struct PrayerJournalPage: View {
    enum Mode: Hashable { case praying, answered, thanks }

    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var mode: Mode = .answered
    @State private var newText = ""
    @State private var slide = 0
    @State private var direction: CGFloat = 1

    var body: some View {
        let prayers = notes.filter { $0.kindValue == .prayer }
        let open = prayers.filter { $0.answeredAt == nil }
        let answered = prayers.filter { $0.answeredAt != nil }.sorted { ($0.answeredAt ?? .distantPast) > ($1.answeredAt ?? .distantPast) }
        let thanks = notes.filter(\.isThanks)
        let items: [Segments<Mode>.Item] = [
            .init(value: .praying, title: "Praying", count: open.count),
            .init(value: .answered, title: "Answered", count: answered.count),
            .init(value: .thanks, title: "Thanks", count: thanks.count),
        ]
        let shown = mode == .praying ? open : (mode == .answered ? answered : thanks)
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Prayer & thanks").rise(0).at(24, 106)
            Lines("\(answered.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine("\(answered.count == 1 ? "Prayer" : "Prayers") answered\n\(thanks.count) thanks written").rise(2).at(24, 292)
            LineArt(drawing: Art.sunrise).at(186, 132)
        } sheet: {
            Segments(items: items, selection: $mode)
            if mode != .answered {
                FieldRow {
                    TextField("", text: $newText, prompt: Text(mode == .thanks ? "Something you're thankful for" : "Something to pray about")
                        .foregroundStyle(Palette.inkFaint))
                        .type(.bodyBold)
                        .foregroundStyle(Palette.ink)
                        .submitLabel(.done)
                        .onSubmit(add)
                    if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add", action: add).buttonStyle(.filledSmall)
                    }
                }
            }
            SheetScroll {
                Group {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, n in
                        Button { router.push(.record(.note(n))) } label: {
                            Row(rule: index < shown.count - 1) {
                                RowText(title: n.displayTitle, subtitle: subtitle(n))
                                WhenText(text: whenText(n.answeredAt ?? n.createdAt))
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if n.kindValue == .prayer && n.answeredAt == nil {
                                Button("Answered") { n.answeredAt = .now }
                            }
                            Button("Delete", role: .destructive) { Store.delete(n, in: ctx) }
                        }
                    }
                    if shown.isEmpty {
                        EmptyRow(title: emptyTitle, message: emptyMessage)
                    }
                }
                .slideIn(slide, direction: direction)
            }
        }
        .onChange(of: mode) { old, new in
            direction = Segments<Mode>.direction(from: old, to: new, in: items)
            slide += 1
        }
        .captureContext(mode == .thanks ? CaptureKind.thanks : CaptureKind.prayer)
    }

    private func subtitle(_ n: Note) -> String {
        if n.isThanks { return "Thankful" }
        if let answered = n.answeredAt {
            let how = n.body.trimmingCharacters(in: .whitespacesAndNewlines)
            return how.isEmpty ? "Answered \(longDate(answered))" : how
        }
        return n.prayedCount > 0 ? "Prayed \(n.prayedCount)× since \(longDate(n.createdAt))" : "Since \(longDate(n.createdAt))"
    }

    private var emptyTitle: String {
        switch mode {
        case .praying: "Nothing on your list yet"
        case .answered: "Answered prayers show up here"
        case .thanks: "Start with one thank-you"
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .praying: "Type one above, or use the +."
        case .answered: "Tap Answered on the Prayer tab when one is."
        case .thanks: "Write down one thing you're thankful for today."
        }
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(Motion.arrive.rm) {
            if mode == .thanks {
                Note.addThanks(text, ctx)
            } else {
                let p = Note()
                p.kindValue = .prayer
                p.title = text
                p.areaValue = .personal
                ctx.insert(p)
            }
        }
        newText = ""
        router.showToast(mode == .thanks ? "Thanks written down" : "Added to Prayer")
        if mode != .thanks { router.popIcon(.prayer) }
    }
}

struct PrayerDetail: View {
    @Bindable var note: Note

    private var aside: String {
        if note.isThanks { return "Thankful for" }
        return note.answeredAt == nil ? "Praying for" : "Answered!"
    }

    private var cap: String {
        if note.isThanks { return "Written \(longDate(note.createdAt))" }
        if let answered = note.answeredAt { return "Answered \(longDate(answered))" }
        return note.prayedCount > 0 ? "Prayed \(note.prayedCount)× since \(longDate(note.createdAt))"
                                    : "Added \(longDate(note.createdAt))"
    }

    var body: some View {
        DetailPage(aside: aside, title: note.displayTitle, cap: cap) {
            FormBlock(note.isThanks ? "Thankful for" : "Prayer") {
                TextRow(note.isThanks ? "Thankful for" : "Prayer point", text: $note.title, vertical: true, lines: 1...6)
            }
            if !note.isThanks {
                FormBlock("Answer") {
                    OptionalDateRow(title: "Answered", date: $note.answeredAt, defaultDate: .now)
                    TextRow(note.answeredAt == nil ? "More about it" : "How it was answered", text: $note.body,
                            vertical: true, lines: 3...12)
                }
                FormBlock("Website", footer: "Visitors see this prayer point, not the notes under it.") {
                    ToggleRow("Show on hesent.me", isOn: $note.isPublic)
                }
            }
            LinksBlock(record: .note(note))
            DeleteButton(item: note)
        }
    }
}

// MARK: - Notes (handoff §7): journal, meetings, ideas

struct NotesPage: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var kind = "all"
    @State private var search = ""
    @State private var slide = 0
    @State private var direction: CGFloat = 1

    private static let kinds: [(NoteKind, String)] = [(.journal, "Journal"), (.meeting, "Meetings"), (.idea, "Ideas"), (.note, "Notes")]

    var body: some View {
        // Prayer points and thanks live on the Prayer tab.
        let all = notes.filter { !$0.isThanks && $0.kindValue != .prayer }
        let items = [Pills<String>.Item(value: "all", title: "All", count: all.count)]
            + Self.kinds.map { Pills<String>.Item(value: $0.0.rawValue, title: $0.1) }
        let filtered = all.filter { n in
            (kind == "all" || n.kind == kind)
                && (search.isEmpty || n.title.localizedCaseInsensitiveContains(search) || n.body.localizedCaseInsensitiveContains(search))
        }
        let shown = filtered.filter(\.pinned) + filtered.filter { !$0.pinned }
        Screen(posterHeight: 306, sheetTop: 16) {
            Hand("Notes & journal").rise(0).at(24, 106)
            Lines("\(all.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine(since(all)).rise(2).at(24, 292)
            // The traveller writing a postcard.
            Picture(.travellerWrite, height: 196).rise(3).at(198, 122)
        } sheet: {
            Pills(items: items, selection: $kind)
            if all.count > 8 {
                SearchField(text: $search, prompt: "Search \(all.count) notes")
            }
            SheetScroll {
                Group {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, n in
                        Button { router.push(.record(.note(n))) } label: {
                            Row(rule: index < shown.count - 1) {
                                if n.pinned {
                                    AnimatedIcon(.pin, size: 16, trigger: 0).foregroundStyle(Palette.ink)
                                }
                                RowText(title: n.displayTitle, subtitle: preview(n))
                                WhenText(text: whenText(n.createdAt))
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(n.pinned ? "Unpin" : "Pin") { n.pinned.toggle() }
                            Button("Delete", role: .destructive) { Store.delete(n, in: ctx) }
                        }
                    }
                    if shown.isEmpty {
                        EmptyRow(title: search.isEmpty ? "No notes yet" : "Nothing matches",
                                 message: search.isEmpty ? "Meeting notes, ideas, a journal of this season." : "Try another word.")
                    }
                }
                .slideIn(slide, direction: direction)
                FormBlock("New") {
                    ForEach(Self.kinds.map(\.0), id: \.self) { k in
                        ActionRow(title: "New \(k.title.lowercased())", icon: k.icon) { newNote(k) }
                    }
                }
            }
        }
        .onChange(of: kind) { old, new in
            direction = Pills<String>.direction(from: old, to: new, in: items)
            slide += 1
        }
        .captureContext(.note)
    }

    private func since(_ all: [Note]) -> String {
        guard let first = all.map(\.createdAt).min() else { return "Nothing written\nyet" }
        let sameYear = Calendar.current.isDate(first, equalTo: .now, toGranularity: .year)
        let month = sameYear ? first.formatted(.dateTime.month(.wide)) : first.formatted(.dateTime.month(.wide).year())
        return "Written since\n\(month)"
    }

    private func preview(_ n: Note) -> String {
        let line = n.body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return String(line.prefix(90))
    }

    private func newNote(_ k: NoteKind) {
        let n = Note()
        n.kindValue = k
        switch k {
        case .journal: n.title = Date.now.formatted(date: .complete, time: .omitted)
        case .meeting: n.title = "Meeting "; n.body = "Who:\n\nWhat we talked about:\n\n\nNext steps:\n- "
        default: break
        }
        ctx.insert(n)
        router.push(.record(.note(n)))
    }
}

/// A note on a paper page: title, kind, the words, and its links.
struct NoteDetail: View {
    @Bindable var note: Note
    @State private var sharePlay = 0

    var body: some View {
        let kinds = NoteKind.allCases.map { Pills<String>.Item(value: $0.rawValue, title: $0.title) }
        PaperPage {
            TitleField(placeholder: "Title", text: $note.title)
            Pills(items: kinds, selection: $note.kind, tight: true)
                .padding(.top, 14)
            TextField("", text: $note.body, prompt: Text("Write…").foregroundStyle(Palette.inkFaint), axis: .vertical)
                .type(.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(10...)
                .padding(.top, 16)
                .padding(.bottom, 8)
            FormBlock("Details") {
                ToggleRow("Pinned", isOn: $note.pinned)
                SelectRow("Area", selection: Binding(get: { note.areaValue }, set: { note.areaValue = $0 })) {
                    ForEach(Area.allCases) { Text($0.title).tag($0) }
                }
                ValueRow(label: "Written", value: longDate(note.createdAt))
            }
            ShareLink(item: "\(note.title)\n\n\(note.body)") {
                HStack(spacing: 10) {
                    AnimatedIcon(.share, size: 18, trigger: sharePlay)
                    Text("Share").type(.bodyBold)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded { sharePlay += 1 })
            LinksBlock(record: .note(note))
            DeleteButton(item: note)
        }
    }
}
