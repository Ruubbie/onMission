import Foundation

// Value lists from the API contract (app/api/openapi.yaml). Raw values are what goes over the wire.

enum Area: String, CaseIterable, Identifiable {
    case visa, admin, finance, support, newsletter, selling, packing, housing, health, insurance, church, travel, ywam, personal, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ywam: "YWAM"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case todo, doing, waiting, done, skipped
    var id: String { rawValue }
    var title: String {
        switch self {
        case .todo: "To do"
        case .doing: "Doing"
        case .waiting: "Waiting"
        case .done: "Done"
        case .skipped: "Skipped"
        }
    }
}

enum Priority: String, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ChecklistPhase: String, CaseIterable, Identifiable {
    case now, beforeDeparture = "before-departure", departureWeek = "departure-week", arrival, ongoing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .now: "Now"
        case .beforeDeparture: "Before departure"
        case .departureWeek: "Departure week"
        case .arrival: "Arrival"
        case .ongoing: "Ongoing"
        }
    }
}

enum PartnerStage: String, CaseIterable, Identifiable {
    case idea, toAsk = "to-ask", asked, thinking, committed, giving, declined, paused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .idea: "On my list"
        case .toAsk: "To ask"
        case .asked: "Asked / meeting"
        case .thinking: "Thinking about it"
        case .committed: "Committed"
        case .giving: "Giving"
        case .declined: "Not now"
        case .paused: "Paused"
        }
    }
    /// Still needs something from you.
    var isOpen: Bool { [.idea, .toAsk, .asked, .thinking].contains(self) }
    /// Counts towards monthly support (as the server's summary does).
    var countsAsSupport: Bool { self == .committed || self == .giving }
}

/// Not in the contract; stored as the extra partner field `category`.
enum PartnerCategory: String, CaseIterable, Identifiable {
    case a = "A", b = "B", c = "C", k = "K"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .a: "A · close, ask in person first"
        case .b: "B · good contact, meet or video call"
        case .c: "C · looser contact, personal message"
        case .k: "K · church, group or business"
        }
    }
}

enum BudgetKind: String, CaseIterable, Identifiable {
    case income, expense, saving
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Recurrence: String, CaseIterable, Identifiable {
    case once, monthly, yearly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum BudgetPhase: String, CaseIterable, Identifiable {
    case setup, monthly
    var id: String { rawValue }
    var title: String { self == .setup ? "Before you go (one-off)" : "Every month" }
}

enum SellStatus: String, CaseIterable, Identifiable {
    case decide, toList = "to-list", listed, reserved, sold, givenAway = "given-away", keep, store
    var id: String { rawValue }
    var title: String {
        switch self {
        case .decide: "Decide"
        case .toList: "To list"
        case .listed: "Listed"
        case .reserved: "Reserved"
        case .sold: "Sold"
        case .givenAway: "Given away"
        case .keep: "Keep (luggage)"
        case .store: "Storage"
        }
    }
    /// Has a final place.
    var isSettled: Bool { [.sold, .givenAway, .keep, .store].contains(self) }
}

enum Bag: String, CaseIterable, Identifiable {
    case checked, carryOn = "carry-on", personal, ship, buyThere = "buy-there", leave
    var id: String { rawValue }
    var title: String {
        switch self {
        case .checked: "Checked bag"
        case .carryOn: "Carry-on"
        case .personal: "Personal item"
        case .ship: "Ship"
        case .buyThere: "Buy there"
        case .leave: "Leave behind"
        }
    }
}

enum NoteKind: String, CaseIterable, Identifiable {
    case note, prayer, journal, meeting, idea
    var id: String { rawValue }
    var title: String {
        switch self {
        case .note: "Note"
        case .prayer: "Prayer"
        case .journal: "Journal"
        case .meeting: "Meeting"
        case .idea: "Idea"
        }
    }
}

enum DocumentKind: String, CaseIterable {
    case passport, visa, insurance, ticket, id, bank, medical, diploma, reference, contract, receipt, letter, other
    var title: String {
        switch self {
        case .id: "ID"
        default: rawValue.capitalized
        }
    }
}

enum NewsletterStatus: String, CaseIterable, Identifiable {
    case idea, draft, ready, sent
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
