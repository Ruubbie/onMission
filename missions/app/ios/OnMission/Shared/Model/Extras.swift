import Foundation
import SwiftData

// Extra fields the redesign needs that the API contract doesn't have. They live in the record's
// `data` (rawData) like the partner's `category`, so the server and the Windows helper keep them.

extension Syncable {
    func extra(_ key: String) -> JSONValue? { Fingerprint.decode(rawData)[key] }

    func setExtra(_ key: String, _ value: JSONValue?) {
        var d = Fingerprint.decode(rawData)
        d[key] = value
        rawData = Fingerprint.encode(d)
    }
}

extension MissionSettings {
    /// Your first name, for "Morning, Ruben!".
    var ownerName: String {
        get { extra("ownerName")?.stringValue ?? "" }
        set { setExtra("ownerName", .text(newValue.trimmingCharacters(in: .whitespaces))) }
    }

    /// "Queenstown, NZ".
    var destination: String {
        get { extra("destination")?.stringValue ?? "Queenstown, NZ" }
        set { setExtra("destination", .text(newValue.trimmingCharacters(in: .whitespaces))) }
    }

    /// "Queenstown".
    var city: String {
        destination.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? destination
    }
}

extension Note {
    /// How many times you tapped I prayed.
    var prayedCount: Int {
        get { extra("prayedCount")?.numberValue.map { Int($0) } ?? 0 }
        set { setExtra("prayedCount", newValue > 0 ? .int(newValue) : nil) }
    }

    var lastPrayedAt: Date? {
        get { extra("lastPrayedAt")?.stringValue.flatMap(TimeFormat.date) }
        set { setExtra("lastPrayedAt", .time(newValue)) }
    }
}

/// Things kept only on this iPhone (not synced): which guides you've read.
enum LocalState {
    static func guideProgress(_ id: String) -> Double {
        UserDefaults.standard.double(forKey: "guide.progress.\(id)")
    }

    static func setGuideProgress(_ id: String, _ value: Double) {
        let current = guideProgress(id)
        UserDefaults.standard.set(max(current, min(value, 1)), forKey: "guide.progress.\(id)")
    }
}
