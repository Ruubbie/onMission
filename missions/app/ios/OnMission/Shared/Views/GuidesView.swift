import SwiftUI

/// Your guides (visa checklist, vision, conversation script, partners, presentations, vision night), inside the app.
struct GuidesView: View {
    struct Guide: Identifiable, Hashable {
        let id: String
        let title: String
        let symbol: String
        let accent: Accent
    }

    static let guides: [Guide] = [
        Guide(id: "visa-en-vertrek-checklist", title: "Visa and leaving NL", symbol: "airplane.departure", accent: .purple),
        Guide(id: "1-visie", title: "Vision", symbol: "eye.fill", accent: .yellow),
        Guide(id: "3-gesprek-script", title: "Support conversation script", symbol: "bubble.left.and.bubble.right.fill", accent: .pink),
        Guide(id: "4-partners", title: "Finding and keeping partners", symbol: "person.2.fill", accent: .pink),
        Guide(id: "5-kerkpresentatie", title: "Church presentations", symbol: "music.mic", accent: .lime),
        Guide(id: "6-visieavond", title: "Vision night and goodbye", symbol: "party.popper.fill", accent: .sand),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Metrics.l) {
                ForEach(Self.guides) { g in
                    NavigationLink { GuideReader(guide: g) } label: {
                        HStack(spacing: Metrics.m) {
                            AccentSquareIcon(symbol: g.symbol, accent: g.accent, size: 40)
                            Text(g.title)
                                .font(Typeface.heading(17))
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(Metrics.m)
                        .brutalBox()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Metrics.l)
            .padding(.trailing, Metrics.shadow)
        }
        .brutalBackground()
        .navigationTitle("Guides")
    }
}

struct GuideReader: View {
    let guide: GuidesView.Guide

    private var text: String {
        let url = Bundle.main.url(forResource: guide.id, withExtension: "md")
            ?? Bundle.main.url(forResource: guide.id, withExtension: "md", subdirectory: "Guides")
        guard let url, let s = try? String(contentsOf: url, encoding: .utf8) else {
            return "This guide isn't in the app bundle. Check that the Resources/Guides folder is part of the target."
        }
        return s
    }

    var body: some View {
        ScrollView {
            MarkdownView(markdown: text)
                .padding(Metrics.l)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .brutalBackground()
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: text) { IconTile(symbol: "square.and.arrow.up", size: 36) }
            }
        }
    }
}

/// A small Markdown renderer: headings, lists, quotes, tables and inline styling. Enough for the guides.
struct MarkdownView: View {
    let markdown: String

    enum Block: Hashable {
        case heading(Int, String), paragraph(String), bullet(String, Int), quote(String), table([[String]]), rule
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
                out.append(.bullet(line, 0))
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
        let blocks = Self.parse(markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(block: block)
            }
        }
        .textSelection(.enabled)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownView.Block

    var body: some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(Typeface.heading(level == 1 ? 28 : level == 2 ? 22 : 18))
                .foregroundStyle(Palette.ink)
                .padding(.top, level <= 2 ? 12 : 4)
        case .paragraph(let text):
            inline(text)
                .font(Typeface.body(16))
                .foregroundStyle(Palette.ink)
        case .bullet(let text, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !(text.first?.isNumber ?? false) {
                    Rectangle().fill(Palette.ink).frame(width: 6, height: 6)
                }
                inline(text).font(Typeface.body(16)).foregroundStyle(Palette.ink)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .quote(let text):
            inline(text)
                .font(Typeface.body(16))
                .italic()
                .foregroundStyle(Palette.ink)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.softYellow)
                .overlay(alignment: .leading) { Rectangle().fill(Palette.ink).frame(width: 4) }
        case .rule:
            Rectangle().fill(Palette.ink).frame(height: Metrics.borderThin).padding(.vertical, 6)
        case .table(let rows):
            MarkdownTable(rows: rows)
        }
    }
}

private struct MarkdownTable: View {
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { col, cell in
                        if !cell.isEmpty {
                            inline(cell)
                                .font(col == 0 ? Typeface.body(15, weight: .bold) : Typeface.body(15))
                                .foregroundStyle(index == 0 ? Palette.muted : Palette.ink)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brutalBox(fill: index == 0 ? Palette.altRow : Palette.paper, radius: Metrics.radiusSmall,
                           shadow: 0, border: Metrics.borderThin)
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
