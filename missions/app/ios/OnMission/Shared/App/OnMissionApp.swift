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
        // Fonts first: Typeface checks once whether Familjen Grotesk is available.
        FontLoader.registerBundledFonts()
        BarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
    }
}

/// Registers every .ttf in the app bundle, so `Font.custom("FamiljenGrotesk-Bold")` works
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

/// The navigation bar in the app's colours and font: no blur, an ink line once content scrolls
/// under it, and a boxed arrow as the back button. The tab bar is our own `FloatingTabBar`.
enum BarAppearance {
    static func apply() {
        let ink = UIColor(Palette.ink)
        let cream = UIColor(Palette.background)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = cream
        nav.shadowColor = ink
        nav.shadowImage = line(ink)
        nav.largeTitleTextAttributes = [.font: font(bold: true, size: 34), .foregroundColor: ink]
        nav.titleTextAttributes = [.font: font(bold: true, size: 17), .foregroundColor: ink]
        let back = backImage()
        nav.setBackIndicatorImage(back, transitionMaskImage: back)
        let hidden: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.clear, .font: UIFont.systemFont(ofSize: 0.1)]
        nav.backButtonAppearance.normal.titleTextAttributes = hidden
        nav.backButtonAppearance.highlighted.titleTextAttributes = hidden

        let top = nav.copy()
        top.shadowColor = .clear
        top.shadowImage = nil

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = top
        UINavigationBar.appearance().tintColor = ink
    }

    /// The 2.5pt ink line under the bar.
    private static func line(_ ink: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: Metrics.border)).image { ctx in
            ink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: Metrics.border))
        }
    }

    /// A 36pt paper square with an ink outline, hard shadow and a bold left arrow.
    private static func backImage() -> UIImage {
        let size: CGFloat = 36, shadow = Metrics.shadowSmall, border = Metrics.border
        let ink = UIColor(Palette.ink), paper = UIColor(Palette.paper)
        let image = UIGraphicsImageRenderer(size: CGSize(width: size + shadow, height: size + shadow)).image { _ in
            let rect = CGRect(x: border / 2, y: border / 2, width: size - border, height: size - border)
            ink.setFill()
            UIBezierPath(roundedRect: rect.offsetBy(dx: shadow, dy: shadow), cornerRadius: Metrics.radiusSmall).fill()
            let box = UIBezierPath(roundedRect: rect, cornerRadius: Metrics.radiusSmall)
            paper.setFill()
            box.fill()
            ink.setStroke()
            box.lineWidth = border
            box.stroke()
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            if let arrow = UIImage(systemName: "arrow.left", withConfiguration: config)?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                arrow.draw(at: CGPoint(x: (size - arrow.size.width) / 2, y: (size - arrow.size.height) / 2))
            }
        }
        return image.withRenderingMode(.alwaysOriginal)
            .withAlignmentRectInsets(UIEdgeInsets(top: 0, left: -8, bottom: -shadow, right: 0))
    }

    private static func font(bold: Bool, size: CGFloat) -> UIFont {
        let name = bold ? "FamiljenGrotesk-Bold" : "FamiljenGrotesk-Regular"
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: bold ? .black : .regular)
    }
}

/// Five tabs (Today, Tasks, Partners, Vault, More), each its own navigation stack kept alive,
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
                .padding(.horizontal, Metrics.l)
                .padding(.bottom, 8)
            }
        }
        .environment(\.floatingBarInset, keyboardShown ? 0 : FloatingTabBar.inset)
        .contentMargins(.bottom, keyboardShown ? 0 : FloatingTabBar.inset, for: .scrollContent)
        .toggleStyle(.brutal)
        .tint(Palette.ink)
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
    case today, tasks, partners, vault, more
    var id: String { rawValue }

    var title: String { self == .vault ? "Vault" : rawValue.capitalized }

    var symbol: String {
        switch self {
        case .today: AppSection.today.symbol
        case .tasks: AppSection.tasks.symbol
        case .partners: AppSection.partners.symbol
        case .vault: AppSection.documents.symbol
        case .more: "square.grid.2x2.fill"
        }
    }

    var accent: Accent {
        switch self {
        case .today, .tasks: .yellow
        case .partners: .pink
        case .vault: .purple
        case .more: .sand
        }
    }

    @MainActor @ViewBuilder
    var root: some View {
        switch self {
        case .today: TodayView()
        case .tasks: TasksView()
        case .partners: PartnersView()
        case .vault: VaultView()
        case .more: MoreView()
        }
    }
}

/// A paper pill floating above the content. The selected tab gets a rounded accent fill that slides.
struct FloatingTabBar: View {
    /// Room screens leave at the bottom for the bar: its height, its gap and its shadow.
    static let inset: CGFloat = 64 + 8 + Metrics.shadow

    let selection: RootTab
    let onSelect: (RootTab) -> Void
    @Namespace private var fill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { t in
                let selected = t == selection
                Button { onSelect(t) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.symbol).font(.system(size: 20, weight: .bold))
                        Text(t.title).font(Typeface.heading(10)).lineLimit(1)
                    }
                    .foregroundStyle(selected ? t.accent.onColor : Palette.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(t.accent.color)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Palette.ink, lineWidth: Metrics.borderThin))
                                .matchedGeometryEffect(id: "fill", in: fill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 64)
        .brutalBox(radius: 22)
        .padding(.trailing, Metrics.shadow)
    }
}

extension EnvironmentValues {
    /// How much of the bottom edge the floating tab bar covers (0 when it's hidden).
    @Entry var floatingBarInset: CGFloat = 0
}
