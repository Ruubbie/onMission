import SwiftUI
import SwiftData

/// Newsletters from idea to sent.
struct NewslettersView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Newsletter.number, order: .reverse) private var letters: [Newsletter]
    @State private var opened: Newsletter?

    var body: some View {
        List {
            ForEach(NewsletterStatus.allCases) { status in
                let rows = letters.filter { $0.statusValue == status }
                if !rows.isEmpty {
                    SectionHeader(status.title, count: rows.count, accent: status.accent)
                        .brutalRow(top: 14, bottom: 2)
                    ForEach(rows) { n in
                        CardLink { NewsletterDetail(letter: n) } label: { NewsletterRow(letter: n) }
                            .brutalRow(top: 4, bottom: 6)
                            .swipeActions {
                                Button("Delete", role: .destructive) { Store.delete(n, in: ctx) }
                            }
                            .contextMenu {
                                ForEach(NewsletterStatus.allCases) { s in
                                    Button(s.title) { NewsletterDetail.setStatus(n, s) }
                                }
                            }
                    }
                }
            }
            if letters.isEmpty {
                BrutalEmptyState(symbol: "envelope.open.fill", title: "No newsletters yet",
                                 message: "Tap + to start one. It comes with a simple structure: a story, what's next, prayer points, thank you.",
                                 accent: .pink)
                    .brutalRow()
            }
            Color.clear.frame(height: 80).brutalRow()
        }
        .brutalList()
        .navigationTitle("Newsletters")
        .addButton(newLetter)
        .navigationDestination(item: $opened) { NewsletterDetail(letter: $0) }
    }

    private func newLetter() {
        let n = Newsletter()
        n.number = (letters.map(\.number).max() ?? 0) + 1
        n.title = "Newsletter \(n.number)"
        n.statusValue = .draft
        n.body = "Opening (what happened, one story):\n\n\nWhat's next:\n\n\nPrayer points:\n- \n\nThank you:\n"
        ctx.insert(n)
        opened = n
    }
}

private struct NewsletterRow: View {
    let letter: Newsletter

    var body: some View {
        HStack(spacing: Metrics.m) {
            Text(letter.number > 0 ? "#\(letter.number)" : "–")
                .font(Typeface.heading(16))
                .foregroundStyle(letter.statusValue.accent.onColor)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: Metrics.radiusSmall).fill(letter.statusValue.accent.color))
                .overlay(RoundedRectangle(cornerRadius: Metrics.radiusSmall).strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
            VStack(alignment: .leading, spacing: 3) {
                Text(letter.displayTitle)
                    .font(Typeface.body(16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Chip(text: letter.statusValue.title, accent: letter.statusValue.accent)
        }
        .padding(Metrics.m)
        .brutalBox(radius: Metrics.radiusSmall, shadow: Metrics.shadowSmall)
    }

    private var detail: String {
        if let sent = letter.sentAt { return "Sent \(longDate(sent))" }
        if let planned = letter.plannedDate { return "Planned \(longDate(planned))" }
        return letter.body.isEmpty ? "Empty" : "\(letter.body.split(whereSeparator: \.isWhitespace).count) words"
    }
}

struct NewsletterDetail: View {
    @Bindable var letter: Newsletter

    static func setStatus(_ n: Newsletter, _ s: NewsletterStatus) {
        n.statusValue = s
        if s == .sent && n.sentAt == nil { n.sentAt = .now }
        if s != .sent { n.sentAt = nil }
    }

    var body: some View {
        Form {
            FormHeroRow(fill: letter.statusValue.accent.color.opacity(0.35)) {
                TextField("Title", text: $letter.title)
                    .font(Typeface.heading(22))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    Chip(text: letter.statusValue.title, accent: letter.statusValue.accent)
                    if letter.number > 0 { Chip(text: "#\(letter.number)", accent: .sand) }
                    Spacer()
                    ShareLink(item: "\(letter.title)\n\n\(letter.body)") { IconTile(symbol: "square.and.arrow.up", size: 36) }
                }
            }
            Section {
                Picker("Status", selection: Binding(get: { letter.statusValue }, set: { Self.setStatus(letter, $0) })) {
                    ForEach(NewsletterStatus.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Number \(letter.number)", value: $letter.number, in: 0...999)
                OptionalDatePicker(title: "Planned for", date: $letter.plannedDate)
                if let sent = letter.sentAt {
                    LabeledContent("Sent", value: longDate(sent))
                }
            } header: { FormHeader("Newsletter") }
            Section {
                TextEditor(text: $letter.body)
                    .font(Typeface.body(16))
                    .frame(minHeight: 320)
            } header: { FormHeader("Text") }
            Section {
                TextField("Web version link", text: $letter.webURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let url = URL(string: letter.webURL), !letter.webURL.isEmpty, url.scheme != nil {
                    Link(destination: url) { Label("Open web version", systemImage: "safari") }
                }
                TextField("Notes (who to send to, photos to use…)", text: $letter.notes, axis: .vertical)
                    .lineLimit(2...8)
            } header: { FormHeader("More") }
            LinksSection(record: .newsletter(letter))
            Section { DeleteRecordButton(item: letter) }
        }
        .brutalForm()
        .navigationTitle(letter.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
