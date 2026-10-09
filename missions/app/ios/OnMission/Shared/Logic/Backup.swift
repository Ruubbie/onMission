import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Backups and CSV files, for the export and import buttons.
/// A backup has the same shape as the server's GET /v1/export, so either can be restored.
enum Backup {
    struct File: Codable {
        var exportedAt: String
        var records: [API.Record]
    }

    static func export(_ ctx: ModelContext) -> Data {
        var records: [API.Record] = []
        for kind in Registry.kinds {
            for m in kind.all(ctx) {
                records.append(API.Record(id: m.id, collection: kind.collection, createdAt: TimeFormat.string(m.createdAt),
                                          updatedAt: TimeFormat.string(m.updatedAt), deletedAt: nil, data: m.data))
            }
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(File(exportedAt: TimeFormat.string(.now), records: records))) ?? Data()
    }

    /// Restores a backup on top of what's here (deleted records in it are skipped).
    /// Restored records count as changed here, so they go up to the server on the next sync.
    static func restore(_ data: Data, _ ctx: ModelContext) throws -> Int {
        let file = try JSONDecoder().decode(File.self, from: data)
        let live = file.records.filter { $0.deletedAt == nil && Registry.kind($0.collection) != nil }
        Registry.apply(live, ctx, force: true)
        let ids = Set(live.map(\.id))
        for kind in Registry.kinds {
            for m in kind.all(ctx) where ids.contains(m.id) { m.syncedFingerprint = "" }
        }
        try ctx.save()
        return live.count
    }

    // MARK: Partners as CSV (for spreadsheets, or your list of 150 names)

    static func partnersCSV(_ partners: [Partner]) -> Data {
        var lines = ["name,category,stage,monthly,one_off,currency,phone,email,church,next_step,next_follow_up,thanked,notes"]
        for p in partners.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let cells = [p.name, p.category, p.stageValue.title, euros(p.monthlyCents), euros(p.oneOffCents), p.currency,
                         p.phone, p.email, p.church, p.nextStep, p.nextFollowUp.map(DayFormat.string) ?? "",
                         p.thankedAt.map(DayFormat.string) ?? "", p.notes]
            lines.append(cells.map(csvCell).joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Reads a CSV or a plain list of names. First column is the name; optional columns: email, phone,
    /// category (A/B/C/K), church. A header row with "name" or "naam" finds the columns.
    /// Names already in the app are skipped. Returns how many were added.
    static func importPartners(_ text: String, _ ctx: ModelContext) -> Int {
        var rows = text.components(separatedBy: .newlines).map(parseCSVLine).filter { !($0.first ?? "").isEmpty }
        guard !rows.isEmpty else { return 0 }
        var col = ["name": 0]
        let header = rows[0].map { $0.lowercased() }
        if header.contains(where: { ["name", "naam"].contains($0) }) {
            for (i, h) in header.enumerated() {
                switch h {
                case "name", "naam": col["name"] = i
                case "email", "e-mail", "mail": col["email"] = i
                case "phone", "telefoon", "tel", "mobile", "mobiel": col["phone"] = i
                case "category", "categorie", "cat": col["category"] = i
                case "church", "kerk", "gemeente": col["church"] = i
                default: break
                }
            }
            rows.removeFirst()
        }
        var existing = Set(Store.all(Partner.self, ctx).map { $0.name.lowercased() })
        var added = 0
        for row in rows {
            func cell(_ key: String) -> String {
                guard let i = col[key], i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespaces)
            }
            let name = cell("name")
            guard !name.isEmpty, !existing.contains(name.lowercased()) else { continue }
            let p = Partner()
            p.name = name
            p.email = cell("email")
            p.phone = cell("phone")
            p.church = cell("church")
            if let c = PartnerCategory(rawValue: cell("category").uppercased()) { p.categoryValue = c }
            ctx.insert(p)
            existing.insert(name.lowercased())
            added += 1
        }
        return added
    }

    private static func euros(_ cents: Int) -> String {
        cents == 0 ? "" : (cents % 100 == 0 ? String(cents / 100) : String(format: "%.2f", Double(cents) / 100))
    }

    private static func csvCell(_ s: String) -> String {
        s.contains(where: { [",", "\"", "\n", ";"].contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
    }

    /// One CSV line; semicolons work too (Dutch Excel).
    static func parseCSVLine(_ line: String) -> [String] {
        let sep: Character = line.contains(";") && !line.contains(",") ? ";" : ","
        var cells: [String] = []
        var cur = ""
        var quoted = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { cur.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if c == sep && !quoted {
                cells.append(cur)
                cur = ""
            } else {
                cur.append(c)
            }
            i += 1
        }
        cells.append(cur)
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

/// Lets the export buttons hand a file to the system save dialog.
struct DataFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
