import Foundation

/// Every screen in the app. Views/Navigation.swift adds `view` for each.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today, tasks, checklists, partners, documents, budget, selling, packing, prayer, notes, newsletters, contacts, guides, search, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .tasks: "Tasks"
        case .checklists: "Checklists"
        case .partners: "Partners"
        case .documents: "Vault"
        case .budget: "Budget"
        case .selling: "Selling"
        case .packing: "Packing"
        case .prayer: "Prayer"
        case .notes: "Notes"
        case .newsletters: "Newsletters"
        case .contacts: "Contacts"
        case .guides: "Guides"
        case .search: "Search"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .tasks: "checkmark.square.fill"
        case .checklists: "checklist"
        case .partners: "person.2.fill"
        case .documents: "lock.doc.fill"
        case .budget: "eurosign.circle.fill"
        case .selling: "tag.fill"
        case .packing: "suitcase.fill"
        case .prayer: "hands.and.sparkles.fill"
        case .notes: "note.text"
        case .newsletters: "envelope.open.fill"
        case .contacts: "person.crop.rectangle.stack.fill"
        case .guides: "book.fill"
        case .search: "magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}
