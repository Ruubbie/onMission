import Foundation

/// The numbers and warnings on the Today screen, worked out from everything you've entered.
/// Money is in EUR cents; NZD amounts are converted with settings.nzdPerEur.
struct Insights {
    let settings: MissionSettings
    let tasks: [Todo]
    let partners: [Partner]
    let gifts: [Gift]
    let budget: [BudgetEntry]
    let sells: [SellItem]
    let packing: [PackingItem]
    let documents: [Document]

    init(settings: MissionSettings, tasks: [Todo], partners: [Partner], gifts: [Gift], budget: [BudgetEntry],
         sells: [SellItem], packing: [PackingItem], documents: [Document]) {
        self.settings = settings
        self.tasks = tasks
        self.partners = partners
        self.gifts = gifts
        self.budget = budget
        self.sells = sells
        self.packing = packing
        self.documents = documents
    }

    private var cal: Calendar { .current }
    private var today: Date { cal.startOfDay(for: .now) }
    private func eur(_ cents: Int, _ currency: String) -> Int { Self.eurCents(cents, currency, settings) }

    // MARK: Countdown

    var daysToGo: Int {
        cal.dateComponents([.day], from: today, to: cal.startOfDay(for: settings.departureDate)).day ?? 0
    }

    // MARK: Support

    /// Monthly gifts of partners who committed or are giving (as the server's summary counts them).
    var committedMonthlyCents: Int {
        partners.filter { $0.stageValue.countsAsSupport }.reduce(0) { $0 + eur($1.monthlyCents, $1.currency) }
    }
    var monthlyPartners: Int { partners.filter { $0.stageValue.countsAsSupport && $0.monthlyCents > 0 }.count }
    var supportProgress: Double {
        settings.supportTargetMonthlyCents > 0
            ? min(Double(committedMonthlyCents) / Double(settings.supportTargetMonthlyCents), 1) : 0
    }
    var stillNeededForMinimumCents: Int { max(settings.supportMinimumMonthlyCents - committedMonthlyCents, 0) }
    var partnersStillNeeded: Int {
        guard settings.averageGiftCents > 0 else { return 0 }
        return Int((Double(stillNeededForMinimumCents) / Double(settings.averageGiftCents)).rounded(.up))
    }
    /// Asked, or thinking about it.
    var openConversations: Int { partners.filter { $0.stageValue == .asked || $0.stageValue == .thinking }.count }

    /// Gifts received this calendar month.
    var giftsThisMonthCents: Int {
        gifts.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + eur($1.amountCents, $1.currency) }
    }

    /// One-off support: per partner the larger of what they pledged (oneOffCents) and the one-off gifts
    /// recorded for them, so a pledge that later arrives as a gift isn't counted twice.
    var oneOffGiftCents: Int {
        let oneOff = gifts.filter { !$0.recurring }
        var total = 0
        for p in partners where p.stageValue != .declined {
            let received = oneOff.filter { $0.partnerID == p.id }.reduce(0) { $0 + eur($1.amountCents, $1.currency) }
            total += max(eur(p.oneOffCents, p.currency), received)
        }
        let known = Set(partners.map(\.id))
        total += oneOff.filter { !known.contains($0.partnerID) }.reduce(0) { $0 + eur($1.amountCents, $1.currency) }
        return total
    }

    /// Open partners whose follow-up is due within 3 days (or overdue).
    var followUps: [Partner] {
        let limit = cal.date(byAdding: .day, value: 3, to: today) ?? today
        return partners
            .filter { $0.stageValue.isOpen && ($0.nextFollowUp.map { $0 <= limit } ?? false) }
            .sorted { ($0.nextFollowUp ?? .distantFuture) < ($1.nextFollowUp ?? .distantFuture) }
    }

    /// Committed or giving but not thanked yet, or a gift came in after the last thank-you.
    var toThank: [Partner] {
        partners.filter { p in
            if p.stageValue.countsAsSupport && p.thankedAt == nil { return true }
            return gifts.contains { g in
                g.partnerID == p.id && g.thankedAt == nil && (p.thankedAt.map { g.date > $0 } ?? true)
            }
        }
        .sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
    }

    // MARK: Tasks (checklist items count too: they're tasks with a due date)

    var overdue: [Todo] { tasks.filter(\.isOverdue).sorted(by: Self.byDue) }
    var thisWeek: [Todo] {
        let end = cal.date(byAdding: .day, value: 7, to: today) ?? today
        return tasks.filter { !$0.isDone && ($0.dueDate.map { $0 >= today && $0 < end } ?? false) }.sorted(by: Self.byDue)
    }
    var openTasks: Int { tasks.filter { !$0.isDone }.count }
    var tasksDone: Int { tasks.filter { $0.statusValue == .done }.count }
    var taskProgress: Double {
        let counted = tasks.filter { $0.statusValue != .skipped }.count
        return counted == 0 ? 0 : Double(tasksDone) / Double(counted)
    }

    static func byDue(_ a: Todo, _ b: Todo) -> Bool {
        let da = a.dueDate ?? .distantFuture
        let db = b.dueDate ?? .distantFuture
        if da != db { return da < db }
        if a.priorityValue != b.priorityValue { return a.priorityValue == .high || b.priorityValue == .low }
        return a.order < b.order
    }

    // MARK: Money

    /// Monthly running costs (yearly ones divided by 12).
    var monthlyBudgetCents: Int {
        budget.filter { $0.kindValue == .expense && ($0.isMonthly || $0.recurrenceValue == .yearly) }
            .reduce(0) { total, b in
                let cents = eur(b.amountCents, b.currency)
                return total + (b.recurrenceValue == .yearly ? Int((Double(cents) / 12).rounded()) : cents)
            }
    }
    /// One-off costs before you go. Savings (like the visa funds proof) aren't spent, so they don't count.
    var setupBudgetCents: Int { setupCosts.reduce(0) { $0 + eur($1.amountCents, $1.currency) } }
    var setupPaidCents: Int { setupCosts.filter(\.paid).reduce(0) { $0 + eur($1.amountCents, $1.currency) } }
    private var setupCosts: [BudgetEntry] {
        budget.filter { $0.kindValue == .expense && !$0.isMonthly && $0.recurrenceValue != .yearly }
    }

    var soldCents: Int { sells.filter { $0.statusValue == .sold }.reduce(0) { $0 + eur($1.soldCents, $1.currency) } }
    var sellPotentialCents: Int {
        sells.filter { ([.decide, .toList, .listed, .reserved] as [SellStatus]).contains($0.statusValue) }
            .reduce(0) { $0 + eur($1.askingCents, $1.currency) }
    }
    var itemsToSort: Int { sells.filter { $0.statusValue == .decide }.count }

    /// Sales, one-off gifts and one-off income lines, measured against the one-off costs.
    var setupCoveredCents: Int {
        let income = budget.filter { $0.kindValue == .income && !$0.isMonthly }.reduce(0) { $0 + eur($1.amountCents, $1.currency) }
        return soldCents + oneOffGiftCents + income
    }
    var setupGapCents: Int { max(setupBudgetCents - setupCoveredCents, 0) }

    // MARK: Packing and vault

    var packed: Int { packing.filter(\.packed).count }
    var packingTotal: Int { packing.count }
    var documentsMissingFile: Int { documents.filter { !$0.hasFile }.count }

    // MARK: Warnings

    struct Warning: Identifiable {
        let id: String
        let text: String
        let record: AnyRecord?
    }

    var warnings: [Warning] {
        var out: [Warning] = []
        let soon = cal.date(byAdding: .day, value: 90, to: today) ?? today
        for d in documents {
            guard let exp = d.expiresAt else { continue }
            if d.kindValue == .passport && exp < settings.passportMustLast {
                out.append(Warning(id: "passport-\(d.id)",
                    text: "Your passport expires \(Self.day(exp)). For the visa it has to last until \(Self.day(settings.passportMustLast)).",
                    record: .document(d)))
            } else if exp < today {
                out.append(Warning(id: "expired-\(d.id)", text: "\(d.displayTitle) expired on \(Self.day(exp)).", record: .document(d)))
            } else if exp < soon {
                out.append(Warning(id: "expires-\(d.id)", text: "\(d.displayTitle) expires \(Self.day(exp)).", record: .document(d)))
            }
        }
        let late = overdue
        if late.count == 1, let t = late.first {
            out.append(Warning(id: "overdue", text: "“\(t.displayTitle)” is overdue.", record: .task(t)))
        } else if late.count > 1 {
            out.append(Warning(id: "overdue", text: "\(late.count) tasks are overdue.", record: nil))
        }
        if daysToGo > 0 && daysToGo <= 45 && committedMonthlyCents < settings.supportMinimumMonthlyCents {
            let avg = Money.text(settings.averageGiftCents, "EUR")
            out.append(Warning(id: "support",
                text: "\(daysToGo) days to go and \(Money.text(stillNeededForMinimumCents, "EUR")) a month still to find for your minimum. That's about \(partnersStillNeeded) partners at \(avg).",
                record: nil))
        }
        if daysToGo > 0 && daysToGo <= 60 && documentsMissingFile > 0 {
            out.append(Warning(id: "vault",
                text: "\(documentsMissingFile) document\(documentsMissingFile == 1 ? " has" : "s have") no file in the vault yet.",
                record: nil))
        }
        return out
    }

    /// EUR cents for any amount: NZD via settings.nzdPerEur. Unknown currencies are left out (0), as on the server.
    static func eurCents(_ cents: Int, _ currency: String, _ s: MissionSettings) -> Int {
        switch currency.uppercased() {
        case "", "EUR": return cents
        case "NZD": return s.nzdPerEur > 0 ? Int((Double(cents) / s.nzdPerEur).rounded()) : 0
        default: return 0
        }
    }

    private static func day(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }
}
