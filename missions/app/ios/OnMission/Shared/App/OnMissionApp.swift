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
        // Fonts first: Typeface checks once whether DM Sans and Lora are available.
        FontLoader.registerBundledFonts()
        BarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

/// Registers every .ttf in the app bundle, so `Font.custom("DMSans-Bold")` works
/// without listing the fonts in Info.plist.
enum FontLoader {
    static func registerBundledFonts() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        urls += Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// The navigation bar in the app's colours and font: see-through over the mocha gradient,
/// a mocha fill once content scrolls under it, and a soft round back button.
enum BarAppearance {
    static func apply() {
        let ink = UIColor(Palette.ink)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(Palette.backgroundTop)
        nav.shadowColor = .clear
        nav.largeTitleTextAttributes = [.font: font(size: 26), .foregroundColor: ink]
        nav.titleTextAttributes = [.font: font(size: 17), .foregroundColor: ink]
        let back = backImage()
        nav.setBackIndicatorImage(back, transitionMaskImage: back)
        let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.clear, .font: UIFont.systemFont(ofSize: 0.1)]
        nav.backButtonAppearance.normal.titleTextAttributes = hidden
        nav.backButtonAppearance.highlighted.titleTextAttributes = hidden

        let top = nav.copy()
        top.configureWithTransparentBackground()
        top.largeTitleTextAttributes = nav.largeTitleTextAttributes
        top.titleTextAttributes = nav.titleTextAttributes
        top.setBackIndicatorImage(back, transitionMaskImage: back)
        top.backButtonAppearance = nav.backButtonAppearance

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = top
        UINavigationBar.appearance().tintColor = ink
    }

    /// A 34pt soft circle with a left chevron.
    private static func backImage() -> UIImage {
        let size: CGFloat = 34
        let ink = UIColor(Palette.ink)
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            UIColor(Palette.chip).setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let arrow = UIImage(systemName: "chevron.left", withConfiguration: config)?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                arrow.draw(at: CGPoint(x: (size - arrow.size.width) / 2 - 1, y: (size - arrow.size.height) / 2))
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
            .withAlignmentRectInsets(UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0))
    }

    private static func font(size: CGFloat) -> UIFont {
        UIFont(name: "DMSans-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
    }
}

/// Five tabs (Today, Tasks, Support, Prayer, More), each its own navigation stack kept alive,
/// under our floating tab bar.
struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @State private var tab: RootTab = .today
    /// Bumped when the selected tab is tapped again, which rebuilds its stack at the top level.
    @State private var resets: [RootTab: Int] = [:]
    @State private var keyboardShown = false

    var body: some View {
        ZStack {
            ForEach(RootTab.allCases) { t in
                NavigationStack { t.root }
                    .id(resets[t, default: 0])
                    .opacity(tab == t ? 1 : 0)
                    .allowsHitTesting(tab == t)
                    .accessibilityHidden(tab != t)
            }
        }
        // The bar floats over the stacks. The safe area doesn't reach into a NavigationStack, so screens
        // learn the bar's height from the environment (the + button) and from content margins (scrolling).
        .overlay(alignment: .bottom) {
            if !keyboardShown {
                FloatingTabBar(selection: tab) { picked in
                    if picked == tab {
                        resets[picked, default: 0] += 1
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) { tab = picked }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .environment(\.floatingBarInset, keyboardShown ? 0 : FloatingTabBar.inset)
        .contentMargins(.bottom, keyboardShown ? 0 : FloatingTabBar.inset, for: .scrollContent)
        .toggleStyle(.brutal)
        .tint(Accent.yellow.color)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardShown = false
        }
        .task {
            Seeder.seedIfNeeded(ctx)
            _ = Store.settings(ctx)
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
}

enum RootTab: String, CaseIterable, Identifiable {
    case today, tasks, support, prayer, more
    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .tasks: "checkmark.square"
        case .support: "heart"
        case .prayer: "hands.and.sparkles"
        case .more: "ellipsis"
        }
    }

    @MainActor @ViewBuilder
    var root: some View {
        switch self {
        case .today: TodayView()
        case .tasks: TasksView()
        case .support: PartnersView()
        case .prayer: PrayerView()
        case .more: MoreView()
        }
    }
}

/// A dark mocha pill floating above the content. The selected tab gets a sage circle that slides.
struct FloatingTabBar: View {
    /// Room screens leave at the bottom for the bar: its height and its gap.
    static let inset: CGFloat = 54 + 8

    let selection: RootTab
    let onSelect: (RootTab) -> Void
    @Namespace private var fill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { t in
                let selected = t == selection
                Button { onSelect(t) } label: {
                    Image(systemName: t.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Palette.onAccent : Palette.tabIcon)
                        .frame(width: 40, height: 40)
                        .background {
                            if selected {
                                Circle().fill(Accent.yellow.color)
                                    .matchedGeometryEffect(id: "fill", in: fill)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 54)
        .background(Capsule().fill(Palette.tabBar).shadow(color: .black.opacity(0.3), radius: 12, y: 6))
    }
}

extension EnvironmentValues {
    /// How much of the bottom edge the floating tab bar covers (0 when it's hidden).
    @Entry var floatingBarInset: CGFloat = 0
}
