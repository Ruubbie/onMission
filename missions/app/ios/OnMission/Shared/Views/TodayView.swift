import SwiftUI
import SwiftData

/// One screen that pulls everything together: days to go, what's next, what's late, and how far you are.
struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var settingsList: [MissionSettings]
    @Query private var tasks: [Todo]
    @Query private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var budget: [BudgetEntry]
    @Query private var sells: [SellItem]
    @Query private var packing: [PackingItem]
    @Query private var documents: [Document]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var quick = ""

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: tasks, partners: partners, gifts: gifts, budget: budget,
                 sells: sells, packing: packing, documents: documents)
    }

    var body: some View {
        let i = insights
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.xl) {
                CountdownCard(insights: i, departure: settings.departureDate)
                QuickAddField(prompt: "Add a task: \"Call Anna friday #support\"", text: $quick, onSubmit: addQuick)
                if !i.warnings.isEmpty { WarningsCard(warnings: i.warnings) }
                TodayTiles(insights: i, documentCount: documents.count, settings: settings)
                ThisWeekCard(tasks: i.overdue + i.thisWeek)
                if !i.followUps.isEmpty || !i.toThank.isEmpty {
                    PeopleCard(followUps: i.followUps, toThank: i.toThank)
                }
                SupportCard(insights: i, settings: settings)
                MoneyCard(insights: i)
                PrayerCard(prayers: notes.filter { $0.kindValue == .prayer && $0.answeredAt == nil })
            }
            .padding(Metrics.l)
            .padding(.trailing, Metrics.shadow)
            .padding(.bottom, Metrics.xl)
        }
        .brutalBackground()
        .navigationTitle("Today")
    }

    private func addQuick() {
        let parsed = QuickAdd.parse(quick)
        guard !parsed.title.isEmpty else { return }
        let t = Automations.addTask(parsed.title, due: parsed.due, area: parsed.area ?? .other, ctx)
        if let p = parsed.priority { t.priorityValue = p }
        quick = ""
    }
}

// MARK: - Pieces of Today

private struct CountdownCard: View {
    let insights: Insights
    let departure: Date

    var body: some View {
        BrutalCard(fill: Accent.yellow.color) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                Text(insights.daysToGo > 0 ? "\(insights.daysToGo)" : "Kia ora!")
                    .font(Typeface.heading(64))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if insights.daysToGo > 0 {
                    Text("days to\nQueenstown")
                        .font(Typeface.heading(18))
                        .foregroundStyle(Palette.ink)
                }
            }
            Text("Flying \(longDate(departure))")
                .font(Typeface.body(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
            BrutalProgress(value: insights.taskProgress, accent: .lime)
            Text("\(insights.tasksDone) tasks done, \(insights.openTasks) to go")
                .font(Typeface.body(13, weight: .medium))
                .foregroundStyle(Palette.ink)
        }
    }
}

private struct WarningsCard: View {
    let warnings: [Insights.Warning]

    var body: some View {
        BrutalCard(fill: Palette.softPink) {
            Label("Heads up", systemImage: "exclamationmark.triangle.fill")
                .font(Typeface.heading(18))
                .foregroundStyle(Palette.ink)
            ForEach(warnings) { w in
                if let rec = w.record {
                    NavigationLink { RecordDestination(record: rec) } label: {
                        HStack {
                            Text(w.text).font(Typeface.body(15)).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Palette.ink)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(w.text).font(Typeface.body(15)).foregroundStyle(Palette.ink)
                }
            }
        }
    }
}

private struct TodayTiles: View {
    let insights: Insights
    let documentCount: Int
    let settings: MissionSettings

    private let columns = [GridItem(.flexible(), spacing: Metrics.l), GridItem(.flexible(), spacing: Metrics.l)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Metrics.xl) {
            NavigationLink { TasksView() } label: {
                FolderTabCard(title: "Tasks", accent: .yellow, symbol: AppSection.tasks.symbol,
                              count: insights.openTasks,
                              subtitle: insights.overdue.isEmpty ? "open" : "\(insights.overdue.count) overdue")
            }
            .buttonStyle(.plain)
            NavigationLink { PartnersView() } label: {
                FolderTabCard(title: "Support", accent: .pink, symbol: AppSection.partners.symbol,
                              count: "\(Int((insights.supportProgress * 100).rounded()))%",
                              subtitle: "\(euros(insights.committedMonthlyCents)) a month")
            }
            .buttonStyle(.plain)
            NavigationLink { VaultView() } label: {
                FolderTabCard(title: "Vault", accent: .purple, symbol: AppSection.documents.symbol,
                              count: documentCount,
                              subtitle: insights.documentsMissingFile > 0 ? "\(insights.documentsMissingFile) without a file" : "documents")
            }
            .buttonStyle(.plain)
            NavigationLink { PackingView() } label: {
                FolderTabCard(title: "Packing", accent: .lime, symbol: AppSection.packing.symbol,
                              count: "\(insights.packed)/\(insights.packingTotal)", subtitle: "packed")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ThisWeekCard: View {
    let tasks: [Todo]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            SectionHeader("This week", count: tasks.count, accent: .yellow)
            BrutalCard {
                if tasks.isEmpty {
                    Text("Nothing due in the next 7 days.")
                        .font(Typeface.body(15))
                        .foregroundStyle(Palette.muted)
                }
                ForEach(Array(tasks.prefix(12).enumerated()), id: \.element.id) { index, t in
                    if index > 0 { Divider().overlay(Palette.hairline) }
                    TaskRow(task: t, opensDetail: true)
                }
                if tasks.count > 12 {
                    Text("And \(tasks.count - 12) more in Tasks.")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

private struct PeopleCard: View {
    let followUps: [Partner]
    let toThank: [Partner]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            SectionHeader("People", count: followUps.count + toThank.count, accent: .pink)
            BrutalCard {
                ForEach(followUps) { p in
                    NavigationLink { PartnerDetail(partner: p) } label: {
                        PersonLine(name: p.displayTitle,
                                   detail: [p.nextStep.isEmpty ? "Follow up" : p.nextStep,
                                            p.nextFollowUp.map(shortDate) ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
                                   symbol: "phone.arrow.up.right", accent: p.stageValue.accent)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(toThank) { p in
                    NavigationLink { PartnerDetail(partner: p) } label: {
                        PersonLine(name: "Thank \(p.displayTitle)", detail: p.stageValue.title,
                                   symbol: "envelope.badge", accent: .green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PersonLine: View {
    let name: String
    let detail: String
    let symbol: String
    let accent: Accent

    var body: some View {
        HStack(spacing: Metrics.m) {
            AccentSquareIcon(symbol: symbol, accent: accent, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(Typeface.body(16, weight: .semibold)).foregroundStyle(Palette.ink)
                if !detail.isEmpty {
                    Text(detail).font(Typeface.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
        }
        .contentShape(Rectangle())
    }
}

private struct SupportCard: View {
    let insights: Insights
    let settings: MissionSettings

    private var reachedMinimum: Bool { insights.committedMonthlyCents >= settings.supportMinimumMonthlyCents }

    var body: some View {
        NavigationLink { PartnersView() } label: {
            BrutalCard {
                Label("Monthly support", systemImage: "heart.fill")
                    .font(Typeface.heading(18))
                    .foregroundStyle(Palette.ink)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(euros(insights.committedMonthlyCents))
                        .font(Typeface.heading(30))
                        .foregroundStyle(Palette.ink)
                    Text("of \(euros(settings.supportTargetMonthlyCents)) a month")
                        .font(Typeface.body(15))
                        .foregroundStyle(Palette.muted)
                }
                BrutalProgress(value: insights.supportProgress, accent: reachedMinimum ? .green : .pink)
                Text(summary)
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var summary: String {
        let base = "\(insights.monthlyPartners) monthly partners, \(insights.openConversations) conversations open."
        if insights.stillNeededForMinimumCents > 0 {
            return base + " About \(insights.partnersStillNeeded) more at \(euros(settings.averageGiftCents)) to reach your minimum of \(euros(settings.supportMinimumMonthlyCents))."
        }
        return base + " Minimum reached."
    }
}

private struct MoneyCard: View {
    let insights: Insights

    var body: some View {
        NavigationLink { BudgetView() } label: {
            BrutalCard {
                Label("Money", systemImage: "eurosign.circle.fill")
                    .font(Typeface.heading(18))
                    .foregroundStyle(Palette.ink)
                StatLine(label: "Monthly budget", value: euros(insights.monthlyBudgetCents))
                StatLine(label: "One-off costs", value: euros(insights.setupBudgetCents))
                StatLine(label: "Covered (sales, gifts, paid)", value: euros(insights.setupCoveredCents))
                if insights.setupBudgetCents > 0 {
                    BrutalProgress(value: Double(insights.setupCoveredCents) / Double(insights.setupBudgetCents), accent: .green)
                }
                if insights.sellPotentialCents > 0 {
                    Text("Still to sell: about \(euros(insights.sellPotentialCents)).")
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PrayerCard: View {
    let prayers: [Note]

    var body: some View {
        if let p = prayers.first {
            NavigationLink { PrayerView() } label: {
                BrutalCard(fill: Palette.softYellow) {
                    Label("Praying for", systemImage: "hands.and.sparkles.fill")
                        .font(Typeface.heading(18))
                        .foregroundStyle(Palette.ink)
                    Text(p.displayTitle)
                        .font(Typeface.body(16))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if prayers.count > 1 {
                        Text("\(prayers.count - 1) more on your prayer list")
                            .font(Typeface.body(13))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
