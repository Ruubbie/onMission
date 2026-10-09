import SwiftUI
import SwiftData

// MARK: - Prayer (notes with kind "prayer")

struct PrayerView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var newText = ""

    private var prayers: [Note] { notes.filter { $0.kindValue == .prayer } }

    var body: some View {
        let open = prayers.filter { $0.answeredAt == nil }
        let answered = prayers.filter { $0.answeredAt != nil }
        List {
            VStack(alignment: .leading, spacing: Metrics.s) {
                QuickAddField(prompt: "Something to pray about", text: $newText, onSubmit: add)
                Text("Share open points in your newsletter; move answered ones to \"Answered\" with a swipe.")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
            }
            .brutalRow(top: 10, bottom: 6)

            SectionHeader("Praying for", count: open.count, accent: .purple).brutalRow(top: 14, bottom: 2)
            ForEach(open) { p in
                CardLink { PrayerDetail(note: p) } label: { PrayerRow(note: p) }
                    .brutalRow(top: 3, bottom: 5)
                    .swipeActions(edge: .leading) {
                        Button("Answered") { p.answeredAt = .now }.tint(Palette.ok)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
                    }
            }
            if !answered.isEmpty {
                SectionHeader("Answered", count: answered.count, accent: .green).brutalRow(top: 14, bottom: 2)
                ForEach(answered) { p in
                    CardLink { PrayerDetail(note: p) } label: { PrayerRow(note: p) }
                        .brutalRow(top: 3, bottom: 5)
                        .swipeActions {
                            Button("Delete", role: .destructive) { Store.delete(p, in: ctx) }
                        }
                }
            }
            Color.clear.frame(height: 40).brutalRow()
        }
        .brutalList()
        .navigationTitle("Prayer")
    }

    private func add() {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let p = Note()
        p.kindValue = .prayer
        p.title = text
        p.areaValue = .personal
        ctx.insert(p)
        newText = ""
    }
}

private struct PrayerRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.m) {
            AccentSquareIcon(symbol: note.answeredAt == nil ? "hands.and.sparkles.fill" : "checkmark.seal.fill",
                             accent: note.answeredAt == nil ? .purple : .green, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.displayTitle)
                    .font(Typeface.body(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if let answered = note.answeredAt {
                    Text("Answered \(longDate(answered))\(note.body.isEmpty ? "" : " · \(note.body)")")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                } else {
                    Text("Since \(longDate(note.createdAt))")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }
}

struct PrayerDetail: View {
    @Bindable var note: Note

    var body: some View {
        Form {
            FormHeroRow(fill: Palette.softYellow) {
                TextField("Prayer point", text: $note.title, axis: .vertical)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                Text("Added \(longDate(note.createdAt))")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
            }
            Section {
                OptionalDatePicker(title: "Answered", date: $note.answeredAt, defaultDate: .now)
                TextField(note.answeredAt == nil ? "More about it" : "How it was answered", text: $note.body, axis: .vertical)
                    .lineLimit(3...12)
            } header: { FormHeader("Answer") }
            LinksSection(record: .note(note))
            Section { DeleteRecordButton(item: note, compact: true) }
        }
        .brutalForm()
        .navigationTitle("Prayer point")
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
            (kind == nil ? n.kindValue != .prayer : n.kindValue == kind)
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
