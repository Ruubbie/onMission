import SwiftUI
import SwiftData

/// The morning check-in: the countdown, thanks, today's cards one at a time, the people waiting on you,
/// support, and anything to watch out for.
struct TodayView: View {
    @Environment(\.selectTab) private var selectTab
    @Query private var settingsList: [MissionSettings]
    @Query private var tasks: [Todo]
    @Query private var partners: [Partner]
    @Query private var gifts: [Gift]
    @Query private var budget: [BudgetEntry]
    @Query private var sells: [SellItem]
    @Query private var packing: [PackingItem]
    @Query private var documents: [Document]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    @State private var showAllWarnings = false

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: tasks, partners: partners, gifts: gifts, budget: budget,
                 sells: sells, packing: packing, documents: documents)
    }

    var body: some View {
        let i = insights
        let dueToday = i.thisWeek.filter { $0.dueDate.map { Calendar.current.isDateInToday($0) } ?? false }
        let deck = i.overdue + dueToday
        let deckIDs = Set(deck.map(\.id))
        let upcoming = i.thisWeek.filter { !deckIDs.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.l) {
                TodayHeader(daysToGo: i.daysToGo)
                ThanksCard(thanks: notes.filter(\.isThanks))
                VStack(alignment: .leading, spacing: Metrics.s) {
                    HStack(alignment: .bottom) {
                        Cap("Today's cards · \(deck.count)")
                        Spacer()
                        if !deck.isEmpty {
                            Ollie(pose: .sit, height: 62)
                                .padding(.trailing, 6)
                                .offset(y: 18)
                        }
                    }
                    .zIndex(3)
                    if deck.isEmpty {
                        RestCard(hasUpcoming: !upcoming.isEmpty)
                    } else {
                        TaskDeck(tasks: deck)
                    }
                    if !upcoming.isEmpty {
                        UpcomingCard(tasks: upcoming) { selectTab(.tasks) }
                    }
                }
                if !i.followUps.isEmpty || !i.toThank.isEmpty {
                    PeopleWaitingCard(followUps: i.followUps, toThank: i.toThank, gifts: gifts)
                }
                SupportStrip(insights: i, settings: settings) { selectTab(.people) }
                if !i.warnings.isEmpty {
                    WarningsCard(warnings: i.warnings, showAll: $showAllWarnings) { selectTab(.tasks) }
                }
            }
            .padding(.horizontal, Metrics.l)
            .padding(.top, 4)
            .padding(.bottom, Metrics.xl)
        }
        .brutalBackground()
        .toolbar(.hidden, for: .navigationBar)
        .captureContext(.task)
    }
}

// MARK: - Pieces of Today

private struct TodayHeader: View {
    let daysToGo: Int

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(Typeface.body(13, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                Text(greeting).font(Typeface.heading(18)).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 8)
            if daysToGo > 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(daysToGo)").font(Typeface.number(30)).foregroundStyle(Palette.ink)
                    Text("days to Queenstown").font(Typeface.body(11, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("Kia ora!").font(Typeface.heading(18)).foregroundStyle(Palette.ink)
            }
        }
    }
}

/// "Start with thanks": the question in Lora, this week's thanks as chips, and + add.
private struct ThanksCard: View {
    @Environment(\.modelContext) private var ctx
    let thanks: [Note]
    @State private var adding = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Cap("Start with thanks")
            Text("What are you thankful for today?")
                .font(Typeface.serif(18))
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 6)
            FlowChips {
                ForEach(Array(thanks.prefix(4).enumerated()), id: \.element.id) { index, n in
                    Text(n.displayTitle)
                        .font(Typeface.body(12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(index == 0 ? Accent.yellow.color.opacity(0.26) : Palette.chip))
                }
                if !adding {
                    Button { adding = true; focused = true } label: {
                        Text("+ add")
                            .font(Typeface.body(12, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .overlay(Capsule().strokeBorder(Palette.ring, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .padding(.vertical, -8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add something you're thankful for")
                }
            }
            if adding {
                TextField("I'm thankful for…", text: $text, prompt: Text("I'm thankful for…").foregroundStyle(Palette.muted))
                    .font(Typeface.body(14))
                    .foregroundStyle(Palette.ink)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Palette.chip))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox()
        .stitched()
    }

    private func save() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { Note.addThanks(t, ctx) }
        text = ""
        adding = false
    }
}

/// Chips that wrap onto new lines.
private struct FlowChips: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews)
        for (index, p) in rows.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y),
                                  proposal: ProposedViewSize(width: min(subviews[index].sizeThatFits(.unspecified).width, bounds.width), height: nil))
        }
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            let w = min(size.width, width)
            if x > 0 && x + w > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += w + spacing
            maxX = max(maxX, x)
            rowHeight = max(rowHeight, size.height)
        }
        return (points, maxX, y + rowHeight)
    }
}

/// Nothing due today: Ollie naps.
private struct RestCard: View {
    let hasUpcoming: Bool

    var body: some View {
        HStack(spacing: Metrics.m) {
            Ollie(pose: .sleep, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing due today").font(Typeface.body(14, weight: .bold)).foregroundStyle(Palette.ink)
                Text(hasUpcoming ? "Ollie's napping. Here's what's coming later this week."
                                 : "Ollie's taking a nap. Tap + when something comes up.")
                    .font(Typeface.body(12.5)).foregroundStyle(Palette.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(radius: 18)
    }
}

/// One cream card on top of two fading ones behind it.
private struct TaskDeck: View {
    let tasks: [Todo]

    var body: some View {
        ZStack(alignment: .top) {
            if tasks.count > 2 { back(scale: 0.88, opacity: 0.45, y: 0) }
            if tasks.count > 1 { back(scale: 0.94, opacity: 0.7, y: 8) }
            if let t = tasks.first {
                TopCard(task: t)
                    .padding(.top, 18)
                    .id(t.id)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: tasks.map(\.id))
    }

    private func back(scale: CGFloat, opacity: Double, y: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            .fill(Cream.fill)
            .frame(height: 150)
            .scaleEffect(x: scale, y: 1, anchor: .top)
            .opacity(opacity)
            .offset(y: y)
    }
}

/// Area, title, when, who it's with, and Tomorrow / Call / Done. Swipe right for done, left for tomorrow.
private struct TopCard: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var openURL
    let task: Todo

    private var when: String {
        guard let due = task.dueDate else { return "Today" }
        if task.isOverdue { return "Was due \(shortDate(due))" }
        return Calendar.current.isDateInToday(due) ? "Due today" : "Due \(shortDate(due))"
    }

    /// The partner this task is about, if it's linked to one.
    private var partner: Partner? {
        for case .partner(let p) in Links.linked(to: .task(task), ctx) { return p }
        return nil
    }

    var body: some View {
        let person = partner
        FocalCard {
            NavigationLink { TaskDetail(task: task) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.map { "\(task.areaValue.title) · \($0.displayTitle)" } ?? task.areaValue.title)
                        .font(Typeface.body(12, weight: .bold))
                        .foregroundStyle(Cream.tag)
                        .lineLimit(1)
                    Text(task.displayTitle)
                        .font(Typeface.body(17, weight: .bold))
                        .foregroundStyle(Cream.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text(when)
                        .font(Typeface.body(13))
                        .foregroundStyle(task.isOverdue ? Color(hex: 0xB0574A) : Cream.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button("Tomorrow", action: tomorrow)
                    .buttonStyle(DeckButtonStyle(fill: Cream.button, ink: Cream.ink))
                if let person, let url = PhoneLinks.call(person.phone) {
                    Button { openURL(url) } label: { Label("Call", systemImage: "phone.fill") }
                        .buttonStyle(DeckButtonStyle(fill: Cream.button, ink: Cream.ink))
                }
                Button("Done", action: done)
                    .buttonStyle(DeckButtonStyle(fill: Accent.yellow.color, ink: Palette.onAccent))
            }
            .padding(.top, 10)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width > 80 { done() } else if v.translation.width < -80 { tomorrow() }
        })
        .accessibilityAction(named: "Done", done)
        .accessibilityAction(named: "Move to tomorrow", tomorrow)
    }

    private func done() {
        withAnimation {
            task.setDone(true)
            Automations.taskDone(task, ctx)
        }
    }

    private func tomorrow() {
        withAnimation {
            task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
        }
    }
}

private struct DeckButtonStyle: ButtonStyle {
    let fill: Color
    let ink: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.body(13, weight: .bold))
            .foregroundStyle(ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// The rest of this week, a few at a time.
private struct UpcomingCard: View {
    let tasks: [Todo]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Cap("Later this week · \(tasks.count)")
                Spacer()
                Button(action: onSeeAll) {
                    Text("All tasks")
                        .font(Typeface.body(12.5, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ForEach(tasks.prefix(4)) { t in
                TaskRow(task: t, opensDetail: true)
            }
            if tasks.count > 4 {
                Text("and \(tasks.count - 4) more")
                    .font(Typeface.body(12.5))
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 38)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(radius: 18)
    }
}

/// Follow-ups due and thanks owed, each with the action right there.
private struct PeopleWaitingCard: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.openURL) private var openURL
    let followUps: [Partner]
    let toThank: [Partner]
    let gifts: [Gift]

    private struct Item: Identifiable {
        let partner: Partner
        let thank: Bool
        var id: String { partner.id + (thank ? "-thank" : "-follow") }
    }

    private var items: [Item] {
        followUps.map { Item(partner: $0, thank: false) } + toThank.map { Item(partner: $0, thank: true) }
    }

    var body: some View {
        let list = items
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader("People waiting on you", count: list.count)
            VStack(spacing: 0) {
                ForEach(list) { item in
                    row(item)
                    if item.id != list.last?.id {
                        Rectangle().fill(Palette.hairline).frame(height: 1).padding(.leading, 56)
                    }
                }
            }
            .brutalBox(radius: 18)
        }
    }

    private func row(_ item: Item) -> some View {
        let p = item.partner
        return HStack(spacing: 10) {
            NavigationLink { PartnerDetail(partner: p) } label: {
                HStack(spacing: 10) {
                    Avatar(name: p.displayTitle, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.displayTitle)
                            .font(Typeface.body(15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(detail(item))
                            .font(Typeface.body(12, weight: .semibold))
                            .foregroundStyle(isLate(item) ? Palette.danger : Palette.tag)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if item.thank {
                Button("Thanked") { withAnimation { p.markThanked(ctx) } }
                    .buttonStyle(BrutalButtonStyle(kind: .primary, compact: true))
                    .accessibilityLabel("Mark \(p.displayTitle) as thanked")
            } else {
                if let url = PhoneLinks.whatsApp(p.phone) {
                    IconButton(symbol: "message.fill", accent: .lime, size: 38, label: "WhatsApp \(p.displayTitle)") { openURL(url) }
                }
                if let url = PhoneLinks.call(p.phone) {
                    IconButton(symbol: "phone.fill", accent: .green, size: 38, label: "Call \(p.displayTitle)") { openURL(url) }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func detail(_ item: Item) -> String {
        let p = item.partner
        if item.thank {
            return p.stageValue.countsAsSupport && p.thankedAt == nil ? "\(p.stageValue.title), not thanked yet" : "A gift to thank for"
        }
        let what = p.nextStep.isEmpty ? "Follow up" : p.nextStep
        guard let when = p.nextFollowUp else { return what }
        return "\(what) · \(shortDate(when))"
    }

    private func isLate(_ item: Item) -> Bool {
        guard !item.thank, let d = item.partner.nextFollowUp else { return false }
        return d < Calendar.current.startOfDay(for: .now)
    }
}

/// Monthly support against the goal; opens People.
private struct SupportStrip: View {
    let insights: Insights
    let settings: MissionSettings
    let onOpen: () -> Void

    var body: some View {
        let stretch = Double(max(settings.supportTargetMonthlyCents, 1))
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Cap("Monthly support")
                    Spacer()
                    Text("\(euros(insights.committedMonthlyCents)) of \(euros(settings.supportTargetMonthlyCents))")
                        .font(Typeface.body(13, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
                BrutalProgress(value: Double(insights.committedMonthlyCents) / stretch, accent: .yellow, height: 8,
                               goal: Double(settings.supportMinimumMonthlyCents) / stretch)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brutalBox(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens People")
    }
}

/// Expiring documents, overdue tasks, the support gap. Two at a time unless you ask for all.
private struct WarningsCard: View {
    let warnings: [Insights.Warning]
    @Binding var showAll: Bool
    let onOpenTasks: () -> Void

    var body: some View {
        let shown = showAll ? warnings : Array(warnings.prefix(2))
        BrutalCard {
            Label("Heads up", systemImage: "exclamationmark.triangle.fill")
                .font(Typeface.body(14, weight: .bold))
                .foregroundStyle(Accent.pink.color)
            ForEach(shown) { w in
                if let rec = w.record {
                    NavigationLink { RecordDestination(record: rec) } label: { line(w.text) }
                        .buttonStyle(.plain)
                } else if w.id == "overdue" {
                    Button(action: onOpenTasks) { line(w.text) }
                        .buttonStyle(.plain)
                } else {
                    Text(w.text).font(Typeface.body(14)).foregroundStyle(Palette.ink)
                }
            }
            if warnings.count > 2 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showAll.toggle() }
                } label: {
                    Text(showAll ? "Show less" : "Show \(warnings.count - 2) more")
                        .font(Typeface.body(13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func line(_ text: String) -> some View {
        HStack {
            Text(text).font(Typeface.body(14)).multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Palette.ink)
        .contentShape(Rectangle())
    }
}
