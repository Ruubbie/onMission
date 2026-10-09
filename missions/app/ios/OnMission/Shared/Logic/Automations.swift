import Foundation
import SwiftData

/// The "smart" part: when something changes, the next step is created and linked for you.
enum Automations {
    private static var cal: Calendar { .current }
    private static var today: Date { cal.startOfDay(for: .now) }
    private static func inDays(_ n: Int) -> Date? { cal.date(byAdding: .day, value: n, to: today) }

    // Titles the rules recognise again later (to close or tick them).
    private static let thankCardPrefix = "Send a thank-you card to "
    private static let thankGiftPrefix = "Thank "
    private static let followUpPrefix = "Follow up with "
    private static let meetingPrefix = "Meeting with "
    private static let firstGiftPrefix = "Check "

    /// Call after a partner's stage changed (the new stage is already set).
    static func partnerStageChanged(_ p: Partner, from old: PartnerStage, _ ctx: ModelContext) {
        let new = p.stageValue
        guard new != old else { return }
        let me = AnyRecord.partner(p)

        switch new {
        case .asked:
            p.lastContact = today
            let when = p.nextFollowUp ?? inDays(3)
            addTask(meetingPrefix + p.displayTitle, due: when, for: me, area: .support, ctx,
                    notes: "Bring the pitch page. Use the conversation script in Guides.")
            if p.nextStep.isEmpty { p.nextStep = "Meeting" }
        case .thinking:
            // Follow up on the agreed day, otherwise after 7 days (from the partners guide).
            let when = p.nextFollowUp ?? inDays(7)
            p.nextFollowUp = when
            p.nextStep = "Call to follow up"
            closeTasks(of: p, prefixes: [meetingPrefix], ctx)
            addTask(followUpPrefix + p.displayTitle, due: when, for: me, area: .support, ctx,
                    notes: "Template B in the partner's Messages menu.")
        case .committed, .giving:
            if p.startDate == nil { p.startDate = today }
            if p.thankedAt == nil {
                addTask(thankCardPrefix + p.displayTitle, due: inDays(2), for: me, area: .support, ctx,
                        notes: "Template C (handwritten, by post). The address is on the partner card.")
            }
            if new == .committed && p.monthlyCents > 0 {
                addTask(firstGiftPrefix + p.firstName + "'s first monthly gift came in",
                        due: cal.date(byAdding: .month, value: 1, to: today), for: me, area: .support, ctx)
            }
            if new == .giving {
                closeTasks(of: p, prefixes: [firstGiftPrefix], ctx)
            }
            p.nextStep = ""
            p.nextFollowUp = nil
            closeTasks(of: p, prefixes: [followUpPrefix, meetingPrefix], ctx)
        case .declined, .paused:
            p.nextStep = ""
            p.nextFollowUp = nil
            closeTasks(of: p, prefixes: [followUpPrefix, meetingPrefix, firstGiftPrefix], ctx)
        case .idea, .toAsk:
            break
        }
    }

    /// Thanked a partner: ticks the thank-you tasks and marks their gifts as thanked.
    static func partnerThanked(_ p: Partner, _ ctx: ModelContext) {
        if p.thankedAt == nil { p.thankedAt = today }
        p.lastContact = today
        closeTasks(of: p, prefixes: [thankCardPrefix, thankGiftPrefix], ctx)
        for g in Store.all(Gift.self, ctx) where g.partnerID == p.id && g.thankedAt == nil {
            g.thankedAt = today
        }
    }

    /// A task was ticked: a thank-you task thanks the partner, a meeting or follow-up counts as contact.
    static func taskDone(_ t: Todo, _ ctx: ModelContext) {
        guard t.statusValue == .done else { return }
        if t.completedAt == nil { t.completedAt = .now }
        for case .partner(let p) in Links.linked(to: .task(t), ctx) {
            if t.title.hasPrefix(thankCardPrefix) || t.title.hasPrefix(thankGiftPrefix) {
                partnerThanked(p, ctx)
            } else if t.title.hasPrefix(followUpPrefix) || t.title.hasPrefix(meetingPrefix) {
                p.lastContact = today
            }
        }
    }

    /// Adds a task, linked to the record it's about. An open task with the same title and link is reused.
    @discardableResult
    static func addTask(_ title: String, due: Date?, for record: AnyRecord? = nil,
                        area: Area = .other, _ ctx: ModelContext, notes: String = "") -> Todo {
        if let record {
            for case .task(let existing) in Links.linked(to: record, ctx) where !existing.isDone && existing.title == title {
                if let due { existing.dueDate = due }
                return existing
            }
        }
        let t = Todo()
        t.title = title
        t.dueDate = due.map { cal.startOfDay(for: $0) }
        t.areaValue = area
        t.notes = notes
        t.order = Date.now.timeIntervalSince1970
        ctx.insert(t)
        if let record { Links.link(.task(t), record, ctx) }
        return t
    }

    /// Records a gift that came in. A monthly gift moves the partner to "giving"; a one-off gets a thank-you task.
    @discardableResult
    static func recordGift(for p: Partner, cents: Int, recurring: Bool, _ ctx: ModelContext) -> Gift {
        let g = Gift()
        g.partnerID = p.id
        g.amountCents = cents
        g.currency = p.currency.isEmpty ? "EUR" : p.currency
        g.date = today
        g.recurring = recurring
        ctx.insert(g)

        if recurring {
            if p.monthlyCents == 0 { p.monthlyCents = cents }
            let old = p.stageValue
            if old != .giving {
                p.stageValue = .giving
                partnerStageChanged(p, from: old, ctx)
            }
        } else {
            addTask(thankGiftPrefix + p.displayTitle + " for the gift", due: inDays(2), for: .partner(p), area: .support, ctx,
                    notes: "Template E in the partner's Messages menu.")
        }
        return g
    }

    private static func closeTasks(of p: Partner, prefixes: [String], _ ctx: ModelContext) {
        for case .task(let t) in Links.linked(to: .partner(p), ctx)
        where !t.isDone && prefixes.contains(where: { t.title.hasPrefix($0) }) {
            t.setDone(true)
        }
    }
}

/// Type a task like you'd say it: "Call Anna friday #support" or "Book flight 20 oct #travel !".
enum QuickAdd {
    struct Parsed {
        var title: String
        var due: Date?
        var area: Area?
        var priority: Priority?
    }

    /// #tags in English or Dutch. Every area's own name works too ("#visa", "#ywam").
    private static let aliases: [String: Area] = [
        "visum": .visa, "gemeente": .admin, "papers": .admin, "money": .finance, "geld": .finance, "bank": .finance,
        "steun": .support, "partner": .support, "partners": .support, "nieuwsbrief": .newsletter, "news": .newsletter,
        "sell": .selling, "verkopen": .selling, "verkoop": .selling, "pack": .packing, "inpakken": .packing,
        "huis": .housing, "wonen": .housing, "house": .housing, "gezondheid": .health, "doctor": .health,
        "arts": .health, "verzekering": .insurance, "kerk": .church, "reis": .travel, "flight": .travel,
        "vlucht": .travel, "nz": .travel, "jmeo": .ywam, "persoonlijk": .personal, "me": .personal,
        "afscheid": .personal, "goodbye": .personal, "overig": .other,
    ]

    static func parse(_ input: String) -> Parsed {
        var words: [String] = []
        var area: Area?
        var priority: Priority?
        for raw in input.split(separator: " ") {
            let word = String(raw)
            let lower = word.lowercased()
            if lower.hasPrefix("#"), lower.count > 1 {
                let tag = String(lower.dropFirst())
                if let a = Area(rawValue: tag) ?? aliases[tag] { area = a; continue }
            }
            switch lower {
            case "!", "!!", "!high", "!hoog", "!urgent": priority = .high; continue
            case "!low", "!laag": priority = .low; continue
            default: break
            }
            words.append(word)
        }
        var text = words.joined(separator: " ")

        var due: Date?
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = detector.firstMatch(in: text, options: [], range: range), let date = match.date,
               let r = Range(match.range, in: text) {
                due = Calendar.current.startOfDay(for: date)
                text.removeSubrange(r)
            }
        }
        // "Call Anna on" / "Pay fee by" after the date is taken out: drop the dangling word.
        var titleWords = text.split(separator: " ").map(String.init)
        if due != nil, let last = titleWords.last, ["on", "by", "at", "op", "voor", "om", "uiterlijk"].contains(last.lowercased()) {
            titleWords.removeLast()
        }
        return Parsed(title: titleWords.joined(separator: " "), due: due, area: area, priority: priority)
    }
}
