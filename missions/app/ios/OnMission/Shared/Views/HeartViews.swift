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

// MARK: - Prayer & thanks (notes with kind "prayer", and thanks)

struct PrayerView: View {
    enum Mode: Hashable { case praying, answered, thanks }

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var newText = ""
    @State private var mode: Mode = .praying

    private var prayers: [Note] { notes.filter { $0.kindValue == .prayer } }
    private var thanks: [Note] { notes.filter(\.isThanks) }

    private var shown: [Note] {
        switch mode {
        case .praying: prayers.filter { $0.answeredAt == nil }
        case .answered: prayers.filter { $0.answeredAt != nil }
        case .thanks: thanks
        }
    }

    private var thanksThisWeek: Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return thanks.filter { $0.createdAt >= start }.count
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: Metrics.m) {
                HStack {
                    Text("Prayer & thanks").font(Typeface.heading(18)).foregroundStyle(Palette.ink)
                    Spacer()
                    Cap("\(prayers.filter { $0.answeredAt == nil }.count) open")
                }
                BrutalSegmented(options: [(value: Mode.praying, label: "Praying"), (value: Mode.answered, label: "Answered"), (value: Mode.thanks, label: "Thanks")],
                                selection: $mode)
                if mode != .answered {
                    QuickAddField(prompt: mode == .thanks ? "Something you're thankful for" : "Something to pray about",
                                  text: $newText, onSubmit: add)
                }
            }
            .brutalRow(top: 8, bottom: 6)

            if shown.isEmpty {
                BrutalEmptyState(symbol: "hands.and.sparkles", title: emptyTitle, ollie: .stand)
                    .brutalRow()
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, p in
                CardLink { PrayerDetail(note: p) } label: { PrayerRow(note: p, focal: index == 0 && mode == .praying) }
                    .brutalRow(top: 3, bottom: 5)
                    .swipeActions(edge: .leading) {
                        if p.kindValue == .prayer && p.answeredAt == nil {
                            Button("Answered") { p.answeredAt = .now }.tint(Palette.ok)
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
                    }
            }

            HStack(spacing: 8) {
                Ollie(pose: .stand, height: 58)
                Text(thanksThisWeek == 0 ? "Write down one thing you're thankful for today."
                     : "You wrote down \(thanksThisWeek) thanks this week.")
                    .font(Typeface.body(12.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4,
                                                       bottomTrailingRadius: 16, topTrailingRadius: 16).fill(Palette.paper))
            }
            .brutalRow(top: 10, bottom: 40)
        }
        .brutalList()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyTitle: String {
        switch mode {
        case .praying: "Nothing on your list yet"
        case .answered: "Answered prayers show up here"
        case .thanks: "Start with one thank-you"
        }
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if mode == .thanks {
            Note.addThanks(text, ctx)
        } else {
            let p = Note()
            p.kindValue = .prayer
            p.title = text
            p.areaValue = .personal
            ctx.insert(p)
        }
        newText = ""
    }
}

private struct PrayerRow: View {
    let note: Note
    var focal: Bool = false

    private var label: String {
        if note.isThanks { return "Thankful · \(longDate(note.createdAt))" }
        return "Since \(longDate(note.createdAt))"
    }

    var body: some View {
        let inkColor = focal ? Cream.ink : Palette.ink
        let sub = focal ? Cream.sub : Palette.muted
        VStack(alignment: .leading, spacing: 6) {
            Cap(label, color: focal ? Cream.tag : Palette.tag)
            Text(note.displayTitle)
                .font(Typeface.serif(15))
                .foregroundStyle(inkColor)
                .multilineTextAlignment(.leading)
            if note.kindValue == .prayer {
                HStack {
                    if let answered = note.answeredAt {
                        Text("Written down \(longDate(answered))").font(Typeface.body(11.5, weight: .semibold)).foregroundStyle(sub)
                        Spacer()
                        Pill(text: "Answered", accent: .green)
                    } else {
                        Text(note.body.isEmpty ? "Swipe right when answered" : note.body)
                            .font(Typeface.body(11.5, weight: .semibold)).foregroundStyle(sub).lineLimit(1)
                        Spacer()
                        Text("Praying")
                            .font(Typeface.body(10.5, weight: .bold))
                            .foregroundStyle(sub)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(focal ? Color(hex: 0xEFE3D8) : Palette.chip))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(fill: focal ? Cream.fill : Palette.paper, radius: 18)
        .stitched(focal ? Cream.stitch : .clear, radius: 18)
    }
}

struct PrayerDetail: View {
    @Bindable var note: Note

    var body: some View {
        Form {
            FormHeroRow {
                TextField(note.isThanks ? "Thankful for" : "Prayer point", text: $note.title, axis: .vertical)
                    .font(Typeface.serif(18))
                    .foregroundStyle(Palette.ink)
                Text("Added \(longDate(note.createdAt))")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
            }
            if !note.isThanks {
            Section {
                OptionalDatePicker(title: "Answered", date: $note.answeredAt, defaultDate: .now)
                TextField(note.answeredAt == nil ? "More about it" : "How it was answered", text: $note.body, axis: .vertical)
                    .lineLimit(3...12)
            } header: { FormHeader("Answer") }
            }
            LinksSection(record: .note(note))
            Section { DeleteRecordButton(item: note, compact: true) }
        }
        .brutalForm()
        .navigationTitle(note.isThanks ? "Thanks" : "Prayer point")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notes, journal, meetings, ideas

struct NotesView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var kind: NoteKind?
    @State private var search = ""
    @State private var opened: Note?

    /// Prayer points have their own screen; they show here only when you pick the Prayer filter.
    private var visible: [Note] {
        let filtered = notes.filter { n in
            !n.isThanks && (kind == nil ? n.kindValue != .prayer : n.kindValue == kind)
                && (search.isEmpty || n.title.localizedCaseInsensitiveContains(search) || n.body.localizedCaseInsensitiveContains(search))
        }
        return filtered.filter(\.pinned) + filtered.filter { !$0.pinned }
    }

    var body: some View {
        List {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(text: "All", accent: .sand, selected: kind == nil) { kind = nil }
                    ForEach(NoteKind.allCases) { k in
                        FilterChip(text: k.title, accent: .sand, symbol: k.symbol, selected: kind == k) {
                            kind = kind == k ? nil : k
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .brutalRow(top: 10, bottom: 6)
            ForEach(visible) { n in
                CardLink { noteDestination(n) } label: { NoteRow(note: n) }
                    .brutalRow(top: 4, bottom: 6)
                    .swipeActions {
                        Button("Delete", role: .destructive) { Store.delete(n, in: ctx) }
                    }
                    .swipeActions(edge: .leading) {
                        Button(n.pinned ? "Unpin" : "Pin") { n.pinned.toggle() }.tint(Accent.yellow.color)
                    }
            }
            if visible.isEmpty {
                BrutalEmptyState(symbol: "note.text", title: "No notes yet",
                                 message: "Meeting notes, ideas, a journal of this season.", accent: .sand)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .brutalSearch(text: $search)
        .navigationTitle("Notes")
        .addMenu {
            ForEach(NoteKind.allCases) { k in
                Button { newNote(k) } label: { Label(k.title, systemImage: k.symbol) }
            }
        }
        .navigationDestination(item: $opened) { noteDestination($0) }
    }

    @ViewBuilder
    private func noteDestination(_ n: Note) -> some View {
        if n.kindValue == .prayer { PrayerDetail(note: n) } else { NoteDetail(note: n) }
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
        opened = n
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.m) {
            AccentSquareIcon(symbol: note.kindValue.symbol, accent: note.kindValue == .prayer ? .purple : .sand, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ink)
                    }
                    Text(note.displayTitle)
                        .font(Typeface.body(16, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                }
                Text("\(note.kindValue.title) · \(longDate(note.createdAt))")
                    .font(Typeface.body(12, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

struct NoteDetail: View {
    @Bindable var note: Note
    @State private var showLinks = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            TextField("Title", text: $note.title)
                .font(Typeface.heading(26))
                .foregroundStyle(Palette.ink)
            HStack(spacing: Metrics.s) {
                Menu {
                    BrutalSelect("Kind", selection: Binding(get: { note.kindValue }, set: { note.kindValue = $0 })) {
                        ForEach(NoteKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                } label: {
                    Chip(text: note.kindValue.title, accent: .sand, symbol: note.kindValue.symbol)
                }
                Menu {
                    BrutalSelect("Area", selection: Binding(get: { note.areaValue }, set: { note.areaValue = $0 })) {
                        ForEach(Area.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Chip(text: note.areaValue.title, accent: note.areaValue.accent)
                }
                Spacer()
                IconButton(symbol: note.pinned ? "pin.fill" : "pin", accent: note.pinned ? Accent.yellow : nil, size: 36,
                           label: note.pinned ? "Unpin" : "Pin") { note.pinned.toggle() }
                ShareLink(item: "\(note.title)\n\n\(note.body)") { IconTile(symbol: "square.and.arrow.up", size: 36) }
                IconButton(symbol: "link", size: 36, label: "Links") { showLinks = true }
            }
            TextEditor(text: $note.body)
                .font(Typeface.body(17))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .padding(Metrics.s)
                .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
        }
        .padding(Metrics.l)
        .padding(.trailing, Metrics.shadowSmall)
        .background(Palette.background.ignoresSafeArea())
        .toolbarBackground(Palette.background, for: .navigationBar)
        .navigationTitle(note.kindValue.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showLinks) {
            LinksScreen(record: .note(note), title: note.displayTitle)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DeleteRecordButton(item: note, compact: true)
            }
        }
    }
}
