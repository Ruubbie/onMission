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

/// The navigation and tab bars in the app's colours and font.
enum BarAppearance {
    static func apply() {
        let ink = UIColor(Palette.ink)
        let cream = UIColor(Palette.background)
        let paper = UIColor(Palette.paper)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = cream
        nav.shadowColor = .clear
        nav.largeTitleTextAttributes = [.font: font(bold: true, size: 34), .foregroundColor: ink]
        nav.titleTextAttributes = [.font: font(bold: true, size: 17), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = ink

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = paper
        tab.shadowColor = ink
        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(Palette.muted)
        item.normal.titleTextAttributes = [.font: font(bold: false, size: 10), .foregroundColor: UIColor(Palette.muted)]
        item.selected.iconColor = ink
        item.selected.titleTextAttributes = [.font: font(bold: true, size: 10), .foregroundColor: ink]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private static func font(bold: Bool, size: CGFloat) -> UIFont {
        let name = bold ? "FamiljenGrotesk-Bold" : "FamiljenGrotesk-Regular"
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: bold ? .black : .regular)
    }
}

/// Tabs: Today, Tasks, Partners, Vault, More.
struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @State private var tab: RootTab = .today

    enum RootTab: Hashable { case today, tasks, partners, vault, more }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: AppSection.today.symbol) }
                .tag(RootTab.today)
            NavigationStack { TasksView() }
                .tabItem { Label("Tasks", systemImage: AppSection.tasks.symbol) }
                .tag(RootTab.tasks)
            NavigationStack { PartnersView() }
                .tabItem { Label("Partners", systemImage: AppSection.partners.symbol) }
                .tag(RootTab.partners)
            NavigationStack { VaultView() }
                .tabItem { Label("Vault", systemImage: AppSection.documents.symbol) }
                .tag(RootTab.vault)
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "square.grid.2x2.fill") }
                .tag(RootTab.more)
        }
        .tint(Palette.ink)
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
