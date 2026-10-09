import Foundation
import CryptoKit

/// A record's `data` as it travels to and from the server (see app/api/openapi.yaml).
typealias JSONObject = [String: JSONValue]

/// Any JSON value. Unknown fields from the server (or from the Windows app) are kept as-is
/// and sent back untouched, as the contract asks.
indirect enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            // Whole numbers go out as integers (cents, counts), so the server sees 1500, not 1500.0.
            if n.rounded() == n, abs(n) < 9.0e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var numberValue: Double? { if case .number(let n) = self { return n }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}

// MARK: - Reading fields

extension Dictionary where Key == String, Value == JSONValue {
    func str(_ key: String, _ fallback: String = "") -> String { self[key]?.stringValue ?? fallback }
    func int(_ key: String, _ fallback: Int = 0) -> Int { self[key]?.numberValue.map { Int($0) } ?? fallback }
    func dbl(_ key: String, _ fallback: Double = 0) -> Double { self[key]?.numberValue ?? fallback }
    func bool(_ key: String, _ fallback: Bool = false) -> Bool { self[key]?.boolValue ?? fallback }
    /// A `YYYY-MM-DD` date field.
    func day(_ key: String) -> Date? { self[key]?.stringValue.flatMap(DayFormat.date) }
    /// An ISO 8601 timestamp field.
    func time(_ key: String) -> Date? { self[key]?.stringValue.flatMap(TimeFormat.date) }
}

// MARK: - Writing fields (nil means "leave the key out")

extension JSONValue {
    static func str(_ s: String) -> JSONValue? { .string(s) }
    /// Empty text is left out, so we don't fill the server with "" for fields never used.
    static func text(_ s: String) -> JSONValue? { s.isEmpty ? nil : .string(s) }
    static func int(_ i: Int) -> JSONValue? { .number(Double(i)) }
    static func dbl(_ d: Double) -> JSONValue? { .number(d) }
    static func flag(_ b: Bool) -> JSONValue? { .bool(b) }
    static func day(_ d: Date?) -> JSONValue? { d.map { .string(DayFormat.string($0)) } }
    static func time(_ d: Date?) -> JSONValue? { d.map { .string(TimeFormat.string($0)) } }
}

/// Calendar dates, "2027-01-05", in the device's own time zone.
enum DayFormat {
    private static let f: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(_ d: Date) -> String { f.string(from: d) }
    static func date(_ s: String) -> Date? { f.date(from: String(s.prefix(10))) }
}

/// Timestamps, "2026-10-08T19:00:00.000Z".
enum TimeFormat {
    private static let withMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()
    static func string(_ d: Date) -> String { withMs.string(from: d) }
    static func date(_ s: String) -> Date? { withMs.date(from: s) ?? plain.date(from: s) }
}

enum Fingerprint {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    /// A short hash of a record's data. If it differs from the last synced one, it changed on this device.
    static func of(_ object: JSONObject) -> String {
        let data = (try? encoder.encode(object)) ?? Data()
        return SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func encode(_ object: JSONObject) -> Data {
        (try? encoder.encode(object)) ?? Data("{}".utf8)
    }

    static func decode(_ data: Data) -> JSONObject {
        (try? JSONDecoder().decode(JSONObject.self, from: data)) ?? [:]
    }
}

/// New record ids are lowercase UUIDs, as the contract requires.
func newID() -> String { UUID().uuidString.lowercased() }
