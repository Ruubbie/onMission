import SwiftUI

// MARK: - Guides (handoff §7): read before you go

/// Your guides (visa checklist, vision, conversation script, partners, presentations, vision night), inside the app.
struct GuidesView: View {
    struct Guide: Identifiable, Hashable {
        let id: String
        let title: String

        private static var cache: [String: String] = [:]

        /// The guide's Markdown, from Resources/Guides.
        var text: String {
            if let cached = Self.cache[id] { return cached }
            let url = Bundle.main.url(forResource: id, withExtension: "md")
                ?? Bundle.main.url(forResource: id, withExtension: "md", subdirectory: "Guides")
            let s = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
                ?? "This guide isn't in the app bundle. Check that the Resources/Guides folder is part of the target."
            Self.cache[id] = s
            return s
        }

        /// Reading time at 200 words a minute.
        var minutes: Int {
            max(1, Int((Double(text.split(whereSeparator: \.isWhitespace).count) / 200).rounded(.up)))
        }

        var progress: Double { LocalState.guideProgress(id) }
    }

    static let guides: [Guide] = [
        Guide(id: "visa-en-vertrek-checklist", title: "Visa and leaving NL"),
        Guide(id: "1-visie", title: "Vision"),
        Guide(id: "3-gesprek-script", title: "Support conversation script"),
        Guide(id: "4-partners", title: "Finding and keeping partners"),
        Guide(id: "5-kerkpresentatie", title: "Church presentations"),
        Guide(id: "6-visieavond", title: "Vision night and goodbye"),
    ]

    @Environment(Router.self) private var router
    @Environment(\.entry) private var entry
    /// Bumped when reading progress changes, so the bars catch up.
    @State private var tick = 0

    var body: some View {
        let _ = tick
        let all = Self.guides
        let read = all.filter { $0.progress >= 1 }.count
        Screen(posterHeight: 306) {
            Hand("Read before you go").rise(0).at(24, 106)
            Lines("\(all.count)", .disp(184), lineHeight: 0.78).rise(1).at(18, 136)
            CapLine("Guides\n\(read) read so far").rise(2).at(24, 292)
            BookArt(trigger: entry).at(190, 150)
        } sheet: {
            SheetScroll {
                SectionHeader("Guides", count: all.count)
                ForEach(Array(all.enumerated()), id: \.element.id) { index, g in
                    Button { router.push(.reader(g)) } label: {
                        Row(rule: index < all.count - 1) {
                            RowText(title: g.title, subtitle: "\(g.minutes) min read")
                            if g.progress >= 1 {
                                HStack(spacing: 4) {
                                    AnimatedIcon(.check, size: 15)
                                    Text("Read").type(TypeStyle(size: 13, wght: 650, relativeTo: .footnote))
                                }
                                .foregroundStyle(Palette.ink)
                            } else {
                                GuideBar(progress: g.progress, delay: 0.5 + Double(index) * 0.09)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(g.progress >= 1 ? "Read" : "\(Int(g.progress * 100)) percent read")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in tick += 1 }
    }
}

/// A 46 × 6 bar that fills to how far you've read.
private struct GuideBar: View {
    let progress: Double
    let delay: Double
    @State private var shown: Double = 0

    var body: some View {
        Capsule()
            .fill(Palette.ink.opacity(0.18))
            .frame(width: 46, height: 6)
            .overlay(alignment: .leading) {
                Capsule().fill(Palette.sageDeep).frame(width: 46 * shown, height: 6)
            }
            .onAppear {
                Motion.after(delay) { withAnimation(.curve(0.2, 0.85, 0.25, 1, 0.8).rm) { shown = progress } }
            }
            .onChange(of: progress) { _, new in withAnimation(.easeOut(duration: 0.4)) { shown = new } }
    }
}

/// The open book; one page turns over once (1.1s, after 1.1s).
private struct BookArt: View {
    let trigger: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            LineArt(drawing: Art.book)
            Clock(trigger: trigger, duration: 2.3) { t in
                let p = seg(t, 1.1, 1.1, Ease(0.5, 0, 0.3, 1))
                let turning = p > 0 && p < 1
                ZStack(alignment: .topLeading) {
                    SVGShape(d: Art.bookRight).fill(Palette.flood)
                    SVGShape(d: Art.bookRight).stroke(Palette.ink, style: StrokeStyle(lineWidth: Metrics.line, lineJoin: .round))
                }
                .frame(width: 180, height: 160, alignment: .topLeading)
                .scaleEffect(x: 1 - 2 * min(p / 0.85, 1), y: 1, anchor: UnitPoint(x: 0.5, y: 85.0 / 160))
                .opacity(turning ? 1 : 0)
            }
        }
        .frame(width: 180, height: 160, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - The reader (a paper page)

private struct ReaderMetrics: PreferenceKey {
    static let defaultValue: [CGFloat] = [0, 0]
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) { value = nextValue() }
}

/// A guide on paper: its title big in ink, the text, and Mark as read. A thin bar under the top bar
/// tracks how far you've scrolled.
struct GuideReader: View {
    let guide: GuidesView.Guide
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    @State private var scrolled: CGFloat = 0
    @State private var saved: Double = 0
    @State private var done = false
    @State private var readPlay = 0

    var body: some View {
        let wasRead = guide.progress >= 1
        GeometryReader { outer in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Lines(wrapLines(guide.title, .disp(62), width: 342, maxLines: 4), .disp(62), lineHeight: 0.9, minScale: 0.6)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.isHeader)
                    MarkdownView(markdown: guide.text, skipTitle: true)
                        .padding(.top, 18)
                    Button { markRead() } label: {
                        ButtonLabel(title: done ? "Read" : (wasRead ? "Read it again" : "Mark as read"), icon: .check, trigger: readPlay)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CapsuleStyle(kind: .filled, wide: true))
                    .pop(readPlay)
                    .padding(.top, 28)
                    ShareLink(item: guide.text) {
                        HStack(spacing: 8) {
                            AnimatedIcon(.share, size: 17)
                            Text("Share this guide").type(.label)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, chrome.top + Metrics.topBar + 8)
                .padding(.bottom, chrome.bar + 28)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { g in
                        Color.clear.preference(key: ReaderMetrics.self, value: [g.frame(in: .named("reader")).minY, g.size.height])
                    }
                }
                .riseSheet()
            }
            .coordinateSpace(name: "reader")
            .onPreferenceChange(ReaderMetrics.self) { v in
                let room = max(v[1] - outer.size.height, 1)
                let f = min(max(-v[0] / room, 0), 1)
                if !done { scrolled = f }
                // Remember how far you got, now and then.
                if Double(f) >= saved + 0.05 || (f >= 0.999 && saved < 1) {
                    saved = Double(f)
                    LocalState.setGuideProgress(guide.id, Double(f) * 0.98)
                }
            }
        }
        .overlay(alignment: .top) {
            ZStack(alignment: .bottom) {
                Paper()
                Capsule()
                    .fill(Palette.ink.opacity(0.15))
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(Palette.sageDeep).frame(width: g.size.width * scrolled)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .offset(y: 3)
            }
            .frame(height: chrome.top + Metrics.topBar)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .paper()
        .foregroundStyle(Palette.ink)
    }

    /// Its check draws and it pops, the bar completes, the list updates, and the reader closes itself.
    private func markRead() {
        readPlay += 1
        withAnimation(.easeOut(duration: 0.2)) { done = true }
        withAnimation(.curve(0, 0, 0.58, 1, 0.4).rm) { scrolled = 1 }
        LocalState.setGuideProgress(guide.id, 1)
        router.showToast("\(guide.title) · read")
        Motion.after(0.8, always: true) { router.back() }
    }
}

// MARK: - Markdown

/// A small Markdown renderer for the guides: headings, lists (numbered ones as big steps), quotes by hand,
/// tables and inline styling.
struct MarkdownView: View {
    let markdown: String
    var skipTitle = false

    enum Block: Hashable {
        case heading(Int, String), paragraph(String), bullet(String, Int), step(String, String), quote(String), table([[String]]), rule
    }

    static func parse(_ markdown: String) -> [Block] {
        var out: [Block] = []
        var table: [[String]] = []
        func flushTable() {
            if !table.isEmpty { out.append(.table(table)); table = [] }
        }
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("|") {
                let cells = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                    .components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                let isDivider = cells.allSatisfy { cell in cell.allSatisfy { "-: ".contains($0) } }
                if !isDivider { table.append(cells) }
                continue
            }
            flushTable()
            if line.isEmpty { continue }
            if line == "---" || line == "***" { out.append(.rule); continue }
            if line.hasPrefix("#") {
                let level = line.prefix { $0 == "#" }.count
                out.append(.heading(level, line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let indent = raw.prefix { $0 == " " }.count / 2
                out.append(.bullet(String(line.dropFirst(2)), indent))
            } else if let dot = line.firstIndex(of: "."), !line[..<dot].isEmpty, line[..<dot].allSatisfy(\.isNumber) {
                out.append(.step(String(line[..<dot]), line[line.index(after: dot)...].trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix(">") {
                out.append(.quote(line.drop { $0 == ">" }.trimmingCharacters(in: .whitespaces)))
            } else {
                out.append(.paragraph(line))
            }
        }
        flushTable()
        return out
    }

    var body: some View {
        var blocks = Self.parse(markdown)
        if skipTitle, case .heading(1, _) = blocks.first { blocks.removeFirst() }
        let leadIndex = blocks.firstIndex { if case .paragraph = $0 { return true } else { return false } }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                MarkdownBlockView(block: block, lead: index == leadIndex && index < 2)
            }
        }
        .textSelection(.enabled)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownView.Block
    var lead = false

    var body: some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .type(level <= 2 ? TypeStyle(size: 26, wght: 820, tracking: -0.035, relativeTo: .title2)
                                 : TypeStyle(size: 17, wght: 650, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
                .padding(.top, level <= 2 ? 14 : 6)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            inline(text)
                .type(lead ? .lead : .body)
                .lineSpacing(lead ? 6 : 4)
                .foregroundStyle(Palette.ink)
        case .bullet(let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(Palette.sageDeep).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                inline(text).type(.body).lineSpacing(4).foregroundStyle(Palette.ink)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .step(let number, let text):
            HStack(alignment: .top, spacing: 16) {
                Text(number)
                    .type(.disp(46))
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 30, alignment: .leading)
                    .offset(y: FontMetrics.shift(size: 46, lineHeight: 0.85))
                inline(text).type(.body).lineSpacing(4).foregroundStyle(Palette.ink.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
            .accessibilityElement(children: .combine)
        case .quote(let text):
            Text(text)
                .type(.hand(30))
                .foregroundStyle(Palette.sageDeep)
                .rotationEffect(.degrees(-2))
                .padding(.vertical, 10)
        case .rule:
            Rectangle().fill(Palette.rule).frame(height: Metrics.rule).padding(.vertical, 6)
        case .table(let rows):
            MarkdownTable(rows: rows)
        }
    }
}

private struct MarkdownTable: View {
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { col, cell in
                        if !cell.isEmpty {
                            inline(cell)
                                .type(col == 0 ? .bodyBold : .body)
                                .foregroundStyle(index == 0 ? Palette.inkSoft : Palette.ink)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    if index < rows.count - 1 { Rectangle().fill(Palette.rule).frame(height: Metrics.rule) }
                }
            }
        }
    }
}

/// Bold, italics, links and code inside a line.
private func inline(_ text: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: text, options: options) {
        return Text(attributed)
    }
    return Text(text)
}
