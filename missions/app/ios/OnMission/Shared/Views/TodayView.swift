import SwiftUI
import SwiftData

/// Thanks first, then one task card at a time, with the countdown and support just below.
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

    /// Cards sent to the back with "Later" (only for this visit).
    @State private var later: [String] = []

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    private var insights: Insights {
        Insights(settings: settings, tasks: tasks, partners: partners, gifts: gifts, budget: budget,
                 sells: sells, packing: packing, documents: documents)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let part = h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening")
        return "\(part), Ruben"
    }

    var body: some View {
        let i = insights
        let deck = order(i.overdue + i.thisWeek)
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.m) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(Typeface.body(13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                    Text(greeting).font(Typeface.heading(18)).foregroundStyle(Palette.ink)
                }
                ThanksCard(thanks: notes.filter(\.isThanks))
                HStack(alignment: .bottom) {
                    Cap("Today's cards · \(deck.count)")
                    Spacer()
                    if !deck.isEmpty {
                        Ollie(pose: .sit, height: 62)
                            .padding(.trailing, 6)
                            .offset(y: 18)
                            .zIndex(3)
                    }
                }
                .zIndex(3)
                if deck.isEmpty {
                    HStack(spacing: Metrics.m) {
                        Ollie(pose: .sleep, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nothing due this week").font(Typeface.body(14, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("Ollie's taking a nap. Add a task in Tasks when something comes up.")
                                .font(Typeface.body(12.5)).foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brutalBox(radius: 18)
                } else {
                    TaskDeck(tasks: deck, onLater: { t in later.removeAll { $0 == t.id }; later.append(t.id) })
                }
                HStack(spacing: Metrics.s) {
                    MiniStat(label: "To Queenstown", value: i.daysToGo > 0 ? "\(i.daysToGo) days" : "Kia ora!")
                    NavigationLink { PartnersView() } label: {
                        MiniStat(label: "Support / month", value: euros(i.committedMonthlyCents))
                    }
                    .buttonStyle(.plain)
                }
                if !i.warnings.isEmpty { WarningsCard(warnings: i.warnings) }
                if !i.followUps.isEmpty || !i.toThank.isEmpty {
                    PeopleCard(followUps: i.followUps, toThank: i.toThank)
                }
            }
            .padding(.horizontal, Metrics.l)
            .padding(.top, 4)
            .padding(.bottom, Metrics.xl)
        }
        .brutalBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Cards put off with Later go to the back, in the order they were put off.
    private func order(_ list: [Todo]) -> [Todo] {
        var seen = Set<String>()
        let unique = list.filter { seen.insert($0.id).inserted }
        let now = unique.filter { !later.contains($0.id) }
        let back = later.compactMap { id in unique.first { $0.id == id } }
        return now + back
    }
}

// MARK: - Pieces of Today

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
                    }
                    .buttonStyle(.plain)
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

/// One cream card on top of two fading ones behind it: area, title, when, and Later / Done.
private struct TaskDeck: View {
    let tasks: [Todo]
    let onLater: (Todo) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if tasks.count > 2 { back(scale: 0.88, opacity: 0.45, y: 0) }
            if tasks.count > 1 { back(scale: 0.94, opacity: 0.7, y: 8) }
            if let t = tasks.first {
                TopCard(task: t, onLater: { onLater(t) })
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

private struct TopCard: View {
    @Environment(\.modelContext) private var ctx
    let task: Todo
    let onLater: () -> Void

    private var when: String {
        guard let due = task.dueDate else { return "This week" }
        return task.isOverdue ? "Was due \(shortDate(due))" : "Due \(shortDate(due))"
    }

    var body: some View {
        FocalCard {
            NavigationLink { TaskDetail(task: task) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.areaValue.title)
                        .font(Typeface.body(12, weight: .bold))
                        .foregroundStyle(Cream.tag)
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
                Button("Later", action: onLater)
                    .buttonStyle(DeckButtonStyle(fill: Cream.button, ink: Cream.ink))
                Button("Done") { withAnimation { task.setDone(true); Automations.taskDone(task, ctx) } }
                    .buttonStyle(DeckButtonStyle(fill: Accent.yellow.color, ink: Palette.onAccent))
            }
            .padding(.top, 10)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.width > 80 { withAnimation { task.setDone(true); Automations.taskDone(task, ctx) } }
            else if v.translation.width < -80 { onLater() }
        })
    }
}

private struct DeckButtonStyle: ButtonStyle {
    let fill: Color
    let ink: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.body(13, weight: .bold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct MiniStat: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(Typeface.body(11, weight: .semibold)).foregroundStyle(Palette.muted)
            Text(value).font(Typeface.body(16, weight: .bold)).foregroundStyle(Palette.ink).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalBox(radius: 14)
    }
}

private struct WarningsCard: View {
    let warnings: [Insights.Warning]

    var body: some View {
        BrutalCard {
            Label("Heads up", systemImage: "exclamationmark.triangle.fill")
                .font(Typeface.body(14, weight: .bold))
                .foregroundStyle(Accent.pink.color)
            ForEach(warnings) { w in
                if let rec = w.record {
                    NavigationLink { RecordDestination(record: rec) } label: {
                        HStack {
                            Text(w.text).font(Typeface.body(14)).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Palette.ink)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(w.text).font(Typeface.body(14)).foregroundStyle(Palette.ink)
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
                Text(name).font(Typeface.body(14, weight: .semibold)).foregroundStyle(Palette.ink)
                if !detail.isEmpty {
                    Text(detail).font(Typeface.body(13)).foregroundStyle(Palette.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .contentShape(Rectangle())
    }
}

