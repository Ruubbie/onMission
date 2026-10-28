import SwiftUI
import SwiftData
import CoreText
import UIKit

@main
struct OnMissionApp: App {
    let container: ModelContainer = {
        let schema = Schema(AppSchema.models)
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
    }()

    init() {
        // Fonts first: TF checks once whether Archivo is available.
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Registers every .ttf in the app bundle, so Archivo works without listing it in Info.plist.
enum FontLoader {
    static func registerBundledFonts() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension EnvironmentValues {
    /// The tab a screen lives in, so Capture knows which screen is on top of which tab.
    @Entry var rootTab: RootTab = .today
}

/// The root (handoff §3, §4): the five tabs kept alive, the page stack on top, the top bar,
/// the tab bar that takes the page colour, and the overlays.
struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    /// `-startTab people`, `-startCapture YES`, `-startPage packing` and `-startPartner YES` open the app
    /// there (for screenshots).
    @State private var router = Router(tab: RootTab(rawValue: UserDefaults.standard.string(forKey: "startTab") ?? "") ?? .today)
    @State private var captureCenter = CaptureCenter()
    @State private var stable = Chrome()

    @Query private var tasks: [Todo]
    @Query private var partners: [Partner]
    @Query private var notes: [Note]

    var body: some View {
        GeometryReader { geo in
            let chrome = chromeFor(geo)
            ZStack(alignment: .top) {
                tabs
                PageLayer()
                if let answered = router.answered {
                    AnsweredLayer(flood: answered)
                }
                TopBar(tabKicker: kicker)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if !router.keyboardShown {
                        TabBar(badges: badges)
                    }
                }
                .ignoresSafeArea(.keyboard)
                toast
                CaptureCover()
                PlusButton()
                if let request = router.checkIn {
                    CheckInView(request: request)
                        .transition(.move(edge: .bottom))
                        .zIndex(10)
                }
                TouchTracker().frame(width: 0, height: 0)
            }
            .environment(\.chrome, chrome)
            .ignoresSafeArea(.container)
            .onAppear { updateStable(geo) }
            .onChange(of: geo.size) { _, _ in updateStable(geo) }
        }
        .environment(router)
        .environment(captureCenter)
        .environment(\.colorScheme, .light)
        .toggleStyle(.paper)
        .tint(Palette.ink)
        // Paper everywhere, so the status bar stays dark.
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            router.keyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            router.keyboardShown = false
        }
        .task {
            Seeder.seedIfNeeded(ctx)
            _ = Store.settings(ctx)
            router.enter()
            openStartPage()
            await Reminders.refresh(ctx)
        }
        .task(id: phase) {
            // Sync when the app comes to the front, then every 2 minutes while it's open.
            guard phase == .active else {
                try? ctx.save()
                return
            }
            while !Task.isCancelled {
                await SyncEngine.shared.sync(ctx)
                try? await Task.sleep(for: .seconds(120))
            }
        }
    }

    // MARK: Pieces

    private var tabs: some View {
        ZStack {
            ForEach(RootTab.allCases) { t in
                tabRoot(t)
                    .environment(\.entry, router.entries[t, default: 0])
                    .environment(\.rootTab, t)
                    .opacity(router.tab == t ? 1 : 0)
                    .animation(nil, value: router.tab)
                    .allowsHitTesting(router.tab == t)
                    .accessibilityHidden(router.tab != t || router.pages.contains { $0.open })
            }
        }
    }

    @ViewBuilder
    private func tabRoot(_ t: RootTab) -> some View {
        switch t {
        case .today: TodayView()
        case .tasks: TasksView()
        case .people: PeopleView()
        case .prayer: PrayerView()
        case .move: MoveView()
        }
    }

    private var toast: some View {
        VStack {
            if let item = router.toast {
                ToastView(text: item.text)
                    .id(item.id)
                    .transition(.asymmetric(insertion: .offset(y: -14).combined(with: .opacity), removal: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, stable.top - 3 + Metrics.topBar)
        .allowsHitTesting(false)
        .zIndex(5)
    }

    // MARK: Data for the chrome

    private var kicker: String {
        switch router.tab {
        case .today, .tasks: Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .people: "\(partners.count) \(partners.count == 1 ? "person" : "people")"
        case .prayer: "Prayer · \(notes.filter { $0.kindValue == .prayer && $0.answeredAt == nil }.count) open"
        case .move: "Move"
        }
    }

    /// A dot on tabs that need you: overdue tasks, partners to follow up or thank.
    private var badges: Set<RootTab> {
        var out = Set<RootTab>()
        if tasks.contains(where: { $0.isOverdue }) { out.insert(.tasks) }
        let today = Calendar.current.startOfDay(for: .now)
        let waiting = partners.contains { p in
            (p.nextFollowUp.map { $0 <= today } ?? false) || p.replyWaiting || (p.wantsToMeet && p.nextFollowUp == nil)
                || (p.stageValue.countsAsSupport && p.thankedAt == nil)
        }
        if waiting { out.insert(.people) }
        return out
    }

    // MARK: Chrome

    private func chromeFor(_ geo: GeometryProxy) -> Chrome {
        var c = stable
        c.width = geo.size.width
        let barContent: CGFloat = 9 + 46
        c.bar = router.keyboardShown ? 0 : barContent + max(c.bottomSafe - 5, 10)
        return c
    }

    /// Insets and height measured while the keyboard is down, so posters don't jump while typing.
    private func updateStable(_ geo: GeometryProxy) {
        guard !router.keyboardShown else { return }
        let insets = geo.safeAreaInsets
        stable = Chrome(top: insets.top, bottomSafe: insets.bottom, width: geo.size.width,
                        height: geo.size.height + insets.top + insets.bottom)
    }

    private func openStartPage() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "startCapture") {
            Motion.after(0.6, always: true) { router.captureOpen = true }
        }
        if defaults.bool(forKey: "startPartner") {
            Motion.after(0.4, always: true) {
                #if DEBUG
                if partners.isEmpty { DemoData.addPartners(ctx) }
                #endif
                let all = Store.all(Partner.self, ctx)
                if let p = all.first(where: { $0.stageValue == .thinking }) ?? all.first {
                    router.push(.partner(p), from: CGPoint(x: 195, y: 520))
                }
            }
        }
        guard let name = defaults.string(forKey: "startPage") else { return }
        let page: Page? = switch name {
        case "checklists": .checklists
        case "vault": .vault
        case "packing": .packing
        case "budget": .budget
        case "selling": .selling
        case "newsletters": .newsletters
        case "notes": .notes
        case "guides": .guides
        case "settings": .settings
        case "allpeople": .allPeople
        default: nil
        }
        if let page {
            Motion.after(0.4, always: true) { router.push(page, from: CGPoint(x: 100, y: 560)) }
        }
    }
}

// MARK: - Top bar

/// Back, the kicker, Settings (on Move) and room for the +, all in ink.
struct TopBar: View {
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    let tabKicker: String

    var body: some View {
        let hasBack = router.top != nil
        let kicker = router.top?.kicker ?? tabKicker
        HStack(spacing: 10) {
            if hasBack {
                RoundButton(icon: .back, label: "Back", trigger: router.pages.count) { router.back() }
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            Text(kicker)
                .type(.kicker)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(kicker)
                .transition(.asymmetric(insertion: .offset(y: 4).combined(with: .opacity), removal: .opacity))
                .accessibilityAddTraits(.isHeader)
            if !hasBack && router.tab == .move {
                RoundButton(icon: .gear, label: "Settings") { router.push(.settings) }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            // The + sits here.
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(Palette.ink)
        .padding(.leading, hasBack ? 16 : Metrics.gutter)
        .padding(.trailing, 18)
        .frame(height: Metrics.topBar)
        .padding(.top, chrome.top - 3)
        .animation(.curve(0.3, 1.2, 0.4, 1, 0.42).rm, value: hasBack)
        .animation(.easeOut(duration: 0.3), value: kicker)
    }
}

/// The + (Capture): an ink circle with a paper plus; while Capture is open it turns into a bare ink ×,
/// and it hides on pushed pages and during the check-in.
struct PlusButton: View {
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    @State private var play = 0

    var body: some View {
        let open = router.captureOpen
        let hidden = (!open && router.pages.contains { $0.open }) || router.checkIn != nil || router.answered != nil
        HStack {
            Spacer()
            Button {
                play += 1
                router.captureOpen.toggle()
            } label: {
                AnimatedIcon(.plus, size: 20, trigger: play)
                    .foregroundStyle(open ? Palette.ink : Palette.paper)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(open ? Color.clear : Palette.ink))
                    .rotationEffect(.degrees(open ? 135 : 0))
                    .contentShape(Circle())
            }
            .buttonStyle(.press)
            .accessibilityLabel(open ? "Close" : "Add or find")
            .sensoryFeedback(.impact(weight: .light), trigger: open)
        }
        .padding(.trailing, 18)
        .frame(height: Metrics.topBar)
        .padding(.top, chrome.top - 3)
        .opacity(hidden ? 0 : 1)
        .scaleEffect(hidden ? 0.5 : 1, anchor: .trailing)
        .allowsHitTesting(!hidden)
        .animation(.curve(0.3, 1.5, 0.5, 1, 0.5).rm, value: open)
        .animation(.easeOut(duration: 0.25), value: hidden)
        .zIndex(20)
    }
}

// MARK: - Tab bar

/// Edge to edge, no hairline. The active tab grows into a pill with its name; the bar takes the page colour.
struct TabBar: View {
    @Environment(Router.self) private var router
    @Environment(\.chrome) private var chrome
    let badges: Set<RootTab>
    @Namespace private var ns

    private struct Colors {
        let bar, ink, pill, on: Color

        init(_ mode: BarMode) {
            switch mode {
            case .paper:
                bar = Palette.paper; ink = Palette.ink.opacity(0.6); pill = Palette.ink; on = Palette.paper
            case .flood:
                bar = Palette.paperDeep; ink = Palette.ink.opacity(0.6); pill = Palette.ink; on = Palette.paperDeep
            case .gold:
                bar = Palette.ochre; ink = Palette.ink.opacity(0.6); pill = Palette.ink; on = Palette.ochre
            }
        }
    }

    var body: some View {
        let mode = router.barMode
        let colors = Colors(mode)
        let active: CGFloat = 126
        let rest = max((chrome.width - 24 - active) / 4, 44)
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { t in
                let on = router.tab == t
                Button { router.select(t) } label: {
                    HStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            AnimatedIcon(t.icon, size: 25, trigger: router.iconPlay[t, default: 0])
                                .modifier(TabPop(trigger: router.iconPop[t, default: 0]))
                            if badges.contains(t) {
                                Circle().fill(colors.pill)
                                    .frame(width: 9, height: 9)
                                    .overlay(Circle().stroke(colors.bar, lineWidth: 2))
                                    .offset(x: 3, y: -1)
                                    .scaleEffect(on ? 0.01 : 1)
                                    .animation(.easeOut(duration: 0.3), value: on)
                            }
                        }
                        Text(t.title)
                            .type(.tab)
                            .lineLimit(1)
                            .fixedSize()
                            .opacity(on ? 1 : 0)
                            .animation(on ? .easeOut(duration: 0.3).delay(0.12) : .easeOut(duration: 0.15), value: on)
                            .frame(width: on ? nil : 0, alignment: .leading)
                            .padding(.leading, on ? 8 : 0)
                            .clipped()
                    }
                    .foregroundStyle(on ? colors.on : colors.ink)
                    .frame(width: on ? active : rest, height: 46)
                    .background {
                        if on {
                            Capsule().fill(colors.pill)
                                .padding(.horizontal, 4)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(badges.contains(t) ? "\(t.title), needs attention" : t.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, max(chrome.bar - 55, 0))
        .frame(maxWidth: .infinity)
        .background(colors.bar)
        .animation(Motion.barFade, value: mode)
        .sensoryFeedback(.selection, trigger: router.tab)
        // Like the system tab bar, the labels stop growing at large text sizes.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
}

private struct TabPopValue {
    var scale: CGFloat = 1
    var angle: Double = 0
}

/// Something was added here: the tab icon pops (1.35 and −8°, 520ms).
private struct TabPop: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: TabPopValue(), trigger: trigger) { view, v in
            view.scaleEffect(v.scale).rotationEffect(.degrees(v.angle))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1.35, duration: 0.22, timingCurve: .easeOut)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
            KeyframeTrack(\.angle) {
                LinearKeyframe(-8, duration: 0.22, timingCurve: .easeOut)
                SpringKeyframe(0, duration: 0.3, spring: .bouncy)
            }
        }
    }
}

// MARK: - Pages

/// A circle that grows from `center` until it covers the whole rect.
struct RevealShape: Shape {
    var center: CGPoint
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let far = corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        let r = max(far * progress, 0)
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    }
}

/// The page stack: each page floods out of where you tapped and folds back into it.
/// The left edge swipes it back, shrinking the circle under your finger.
struct PageLayer: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            ZStack {
                ForEach(router.pages) { entry in
                    let isTop = entry.id == router.pages.last?.id
                    let progress: CGFloat = entry.open ? (isTop ? 1 - router.dragBack * 0.9 : 1) : 0
                    PageHost(entry: entry)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .mask {
                            RevealShape(center: CGPoint(x: entry.origin.x - frame.minX, y: entry.origin.y - frame.minY),
                                        progress: reduce ? 1 : progress)
                        }
                        .opacity(reduce ? (entry.open ? 1 : 0) : 1)
                        .allowsHitTesting(entry.open)
                        .overlay(alignment: .leading) {
                            if isTop && entry.open {
                                edgeSwipe(width: geo.size.width)
                            }
                        }
                }
            }
        }
    }

    private func edgeSwipe(width: CGFloat) -> some View {
        Color.clear
            .frame(width: 20)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .onChanged { v in
                        router.dragBack = min(max(v.translation.width / width, 0), 1)
                    }
                    .onEnded { v in
                        if v.translation.width > width * 0.33 || v.predictedEndTranslation.width > width * 0.5 {
                            router.back()
                        } else {
                            withAnimation(.spring(k: 300, c: 30)) { router.dragBack = 0 }
                        }
                    }
            )
            .accessibilityHidden(true)
    }
}

/// One page: its own entry trigger, so its poster rises and its drawing draws once the flood has started.
private struct PageHost: View {
    @Environment(Router.self) private var router
    let entry: PageEntry
    @State private var shown = 0

    var body: some View {
        PageView(page: entry.page)
            .environment(\.entry, shown)
            .environment(\.entryDelay, 0.14)
            .onAppear { shown += 1 }
            // VoiceOver's two-finger scrub goes back, like the edge swipe.
            .accessibilityAction(.escape) { router.back() }
    }
}

/// Which view each page shows.
struct PageView: View {
    let page: Page

    var body: some View {
        switch page {
        case .checklists: ChecklistsPage()
        case .checklist(let list): ChecklistDetail(list: list)
        case .vault: VaultPage()
        case .documents: DocumentsPage()
        case .packing: PackingPage()
        case .budget: BudgetPage()
        case .selling: SellingPage()
        case .sellAll: SellAllPage()
        case .newsletters: NewslettersPage()
        case .notes: NotesPage()
        case .guides: GuidesView()
        case .reader(let guide): GuideReader(guide: guide)
        case .partner(let p): PartnerPage(partner: p)
        case .allPeople: AllPeoplePage()
        case .contacts: ContactsPage()
        case .task(let t): TaskPage(task: t)
        case .settings: SettingsView()
        case .search: SearchPage()
        case .prayerJournal: PrayerJournalPage()
        case .record(let r): RecordDestination(record: r)
        }
    }
}

// MARK: - Answered

/// An ochre circle floods out of the Answered button: the words as an aside, a sunrise draws itself and a
/// pink flower from hesent.me sits in the grass.
struct AnsweredLayer: View {
    let flood: AnsweredFlood
    @Environment(\.chrome) private var chrome
    @Environment(\.dynamicTypeSize) private var dts
    @State private var shown = 0

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let k = chrome.posterScale(dts)
            VStack(spacing: 0) {
                Color.clear.frame(height: chrome.top + Metrics.topBar)
                PosterCanvas(height: 520, scale: k) {
                    Lines("Answered!", .disp(74)).rise(0).offset(x: 22, y: 130 - 104)
                    Text(flood.text)
                        .type(.hand(29))
                        .lineLimit(4)
                        .frame(width: 342, alignment: .leading)
                        .rotationEffect(.degrees(-2))
                        .rise(1)
                        .offset(x: 24, y: 214 - 104)
                    LineArt(drawing: Art.sunrise, ink: .onGold, delay: 0.26).offset(x: 95, y: 318 - 104)
                    Picture(.flowerPink, height: 46, tilt: -16).rise(2).offset(x: 292, y: 452 - 104)
                    CapLine("Saved in Prayer & thanks", size: 18)
                        .frame(width: 390)
                        .rise(2)
                        .offset(y: 540 - 104)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.ink)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Palette.ochre)
            .environment(\.entry, shown)
            .environment(\.entryDelay, 0.16)
            .mask {
                RevealShape(center: CGPoint(x: flood.origin.x - frame.minX, y: flood.origin.y - frame.minY),
                            progress: flood.open ? 1 : 0)
            }
            .onAppear { shown += 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Answered! \(flood.text). Saved in Prayer and thanks.")
        .sensoryFeedback(.success, trigger: shown)
    }
}
