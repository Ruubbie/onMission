import SwiftUI
import SwiftData

/// Today (handoff §5): days till you leave, big on tomato; the one most urgent task as a hero card;
/// the rest of today as rows. Clear the day and the sheet drops: All done.
struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.entry) private var entry
    @Query private var settingsList: [MissionSettings]
    @Query private var tasks: [Todo]
    @Query private var partners: [Partner]

    @State private var leaving = false
    @State private var heroPlay = 0
    @State private var doneDraw = 0

    private var settings: MissionSettings { settingsList.first ?? MissionSettings() }

    var body: some View {
        let i = Insights(settings: settings, tasks: tasks, partners: partners, gifts: [], budget: [],
                         sells: [], packing: [], documents: [])
        let dueToday = i.thisWeek.filter { $0.dueDate.map { Calendar.current.isDateInToday($0) } ?? false }
        let deck = i.overdue + dueToday
        let allDone = deck.isEmpty
        ZStack(alignment: .top) {
            Screen(posterHeight: 300, dropped: allDone) {
                poster(days: max(i.daysToGo, 0))
            } sheet: {
                SheetScroll { sheet(deck) }
            }
            if allDone {
                doneArt
                    .transition(.opacity.animation(.easeOut(duration: 0.4).delay(0.35)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: allDone)
        .onAppear { router.todayAllDone = allDone }
        .onChange(of: allDone) { _, now in
            router.todayAllDone = now
            if now { doneDraw += 1 }
        }
        .captureContext(.task)
    }

    // MARK: Poster

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let part = h < 12 ? "Morning" : (h < 18 ? "Afternoon" : "Evening")
        let name = settings.ownerName
        return name.isEmpty ? "\(part)!" : "\(part), \(name)!"
    }

    @ViewBuilder
    private func poster(days: Int) -> some View {
        Hand(greeting, size: 36).rise(0).at(24, 108)
        CountUp(value: days, trigger: entry, duration: 1)
            .type(.disp(218))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(width: 210, alignment: .leading)
            .offset(y: FontMetrics.shift(.archivo, size: 218, lineHeight: 0.78))
            .rise(1)
            .at(18, 150)
        CapLine("Days till \(settings.city)").rise(2).at(24, 332)
        LineArt(drawing: Art.mountain).at(208, 140)
    }

    // MARK: Sheet

    @ViewBuilder
    private func sheet(_ deck: [Todo]) -> some View {
        SectionHeader("Next up", count: "\(deck.count) today")
        if let hero = deck.first {
            heroCard(hero)
                .id(hero.id)
                .offset(x: leaving ? 40 : 0)
                .opacity(leaving ? 0 : 1)
                .transition(.asymmetric(insertion: .offset(y: 22).combined(with: .opacity), removal: .identity))
        }
        let rest = Array(deck.dropFirst())
        if !rest.isEmpty {
            SectionHeader("Later today", count: rest.count)
            ForEach(rest.prefix(3)) { t in
                TaskRow(task: t, subtitle: subtitle(t), when: nil, rule: t.id != rest.prefix(3).last?.id)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
            }
            if rest.count > 3 {
                MoreLink(title: "+\(rest.count - 3) more today") { router.select(.tasks) }
            }
        }
    }

    private func subtitle(_ t: Todo) -> String {
        if t.isOverdue, let due = t.dueDate { return "Was due \(shortDate(due, midSentence: true))" }
        if let p = partner(for: t) { return "\(t.areaValue.title) · \(p.displayTitle)" }
        return t.areaValue.title
    }

    private func partner(for t: Todo) -> Partner? {
        for case .partner(let p) in Links.linked(to: .task(t), ctx) { return p }
        return nil
    }

    private func heroCard(_ t: Todo) -> some View {
        let person = partner(for: t)
        let callable = person.flatMap { PhoneLinks.call($0.phone) } != nil
        return HeroCard(title: t.displayTitle, subtitle: subtitle(t), late: t.isOverdue) {
            if let person, let url = PhoneLinks.call(person.phone) {
                ActionButton(title: "Call", icon: .phone) {
                    openURL(url)
                    router.openCheckIn(CheckInRequest(partner: person, task: t))
                }
                ActionButton(title: "Done", style: .outlined) { finish(t) }
            } else {
                ActionButton(title: "Done", icon: .check) { finish(t) }
                ActionButton(title: "Tomorrow", style: .outlined) { tomorrow(t) }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { router.push(.task(t)) }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open") { router.push(.task(t)) }
        .accessibilityHint(callable ? "Call, then tell how it went" : "")
    }

    /// The card slides out to the right; the next one rises in.
    private func finish(_ t: Todo) {
        withAnimation(Motion.leave.rm) { leaving = true }
        Motion.after(0.3) {
            withAnimation(Motion.arrive.rm) {
                t.setDone(true)
                Automations.taskDone(t, ctx)
                leaving = false
            }
        }
    }

    private func tomorrow(_ t: Todo) {
        router.showToast("Moved to tomorrow")
        withAnimation(Motion.leave.rm) { leaving = true }
        Motion.after(0.3) {
            withAnimation(Motion.arrive.rm) {
                t.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))
                leaving = false
            }
        }
    }

    // MARK: All done

    private var doneArt: some View {
        let name = settings.ownerName
        return VStack(spacing: 0) {
            PosterCanvas(height: 640, scale: 1) {
                Lines("All\ndone.", .disp(128)).at(22, 128)
                Hand(name.isEmpty ? "Go enjoy the evening" : "Go enjoy the evening, \(name)", size: 34, tilt: -4).at(26, 368)
                LineArt(drawing: Art.hammock, delay: 0.38, trigger: doneDraw).at(80, 430)
                // Ollie's one cameo: asleep, small, under the hammock.
                Ollie(pose: .sleep, height: 54).at(300, 590)
            }
            Spacer(minLength: 0)
        }
        .modifier(ChromeOffset())
        .foregroundStyle(Palette.cream)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("All done. Go enjoy the evening.")
    }
}

/// Places a poster canvas under the top bar, scaled like every other poster.
private struct ChromeOffset: ViewModifier {
    @Environment(\.chrome) private var chrome
    @Environment(\.dynamicTypeSize) private var dts

    func body(content: Content) -> some View {
        let k = chrome.posterScale(dts)
        content
            .scaleEffect(k, anchor: .topLeading)
            .padding(.top, chrome.top + Metrics.topBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A number that counts up from `from` each time `trigger` changes (ease-out cubic).
struct CountUp: View {
    let value: Int
    var from: Int = 0
    var trigger: Int
    var duration: Double = 1
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        Clock(trigger: trigger, duration: duration) { t in
            let k = t >= duration ? 1 : Ease.outCubic(t / duration)
            Text(format(Int((Double(from) + Double(value - from) * k).rounded())))
                .monospacedDigit()
        }
    }
}
