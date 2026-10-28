import SwiftUI
import SwiftData
import UIKit
import UIKit.UIGestureRecognizerSubclass

// Navigation (handoff §3, §4, §7): five tabs, a stack of pages that flood out of what you tapped, and the
// overlays (Capture, the check-in, Answered, the toast). The bar mode follows from this state. Everything is
// light paper with ink on it, so the status bar is always dark.

enum RootTab: String, CaseIterable, Identifiable {
    case today, tasks, people, prayer, move
    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var icon: Icon {
        switch self {
        case .today: .sun
        case .tasks: .list
        case .people: .users
        case .prayer: .flame
        case .move: .plane
        }
    }
}

/// The tab bar takes the colour of whatever sits at the bottom of the screen: the sheet's paper, the poster's
/// deeper paper, or the Answered ochre.
enum BarMode {
    case paper, flood, gold
}

/// What a page has at the bottom: a paper sheet, nothing but poster, or a whole paper page.
enum PageStyle {
    case sheet, flood, paper
}

/// Every pushed page.
enum Page {
    case checklists, checklist(Checklist), vault, documents, packing, budget, selling, sellAll, newsletters, notes
    case guides, reader(GuidesView.Guide)
    case partner(Partner), allPeople, contacts
    case task(Todo)
    case settings, search, prayerJournal
    case record(AnyRecord)

    var kicker: String {
        switch self {
        case .checklists: "Checklists"
        case .checklist: "Checklist"
        case .vault: "Vault"
        case .documents: "All papers"
        case .packing: "Packing"
        case .budget: "Budget"
        case .selling: "Selling"
        case .sellAll: "Everything you own"
        case .newsletters: "Newsletters"
        case .notes: "Notes"
        case .guides: "Guides"
        case .reader(let g): "Guide · \(g.minutes) min read"
        case .partner, .allPeople: "People"
        case .contacts: "Contacts"
        case .task: "Task"
        case .settings: "Settings"
        case .search: "Find anything"
        case .prayerJournal: "Prayer & thanks"
        case .record(let r): r.typeLabel
        }
    }

    var style: PageStyle {
        switch self {
        case .reader, .search: .paper
        case .record(.note(let n)) where n.kindValue != .prayer && !n.isThanks: .paper
        default: .sheet
        }
    }
}

struct PageEntry: Identifiable {
    let id = UUID()
    let page: Page
    /// Where it floods out of, in window coordinates.
    let origin: CGPoint
    var open = false
}

/// Who the check-in is about, and the task it closes (a call from Today).
struct CheckInRequest: Identifiable {
    let id = UUID()
    let partner: Partner
    var task: Todo? = nil
}

/// The Answered flood: the prayer's words and where the gold comes from.
struct AnsweredFlood: Identifiable {
    let id = UUID()
    let text: String
    let origin: CGPoint
    var open = false
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

@MainActor @Observable final class Router {
    var tab: RootTab
    var pages: [PageEntry] = []
    /// Bumped when a tab comes into view: its poster rises and its drawing draws.
    var entries: [RootTab: Int] = [:]
    /// Bumped to play a tab icon's motion.
    var iconPlay: [RootTab: Int] = [:]
    /// Bumped to make a tab icon pop (something was added there).
    var iconPop: [RootTab: Int] = [:]
    var captureOpen = false
    var checkIn: CheckInRequest?
    var answered: AnsweredFlood?
    var todayAllDone = false
    var toast: ToastItem?
    /// How far the top page has been dragged back by the edge swipe (0...1).
    var dragBack: CGFloat = 0
    var keyboardShown = false

    init(tab: RootTab = .today) {
        self.tab = tab
    }

    // MARK: Tabs

    func select(_ picked: RootTab) {
        if picked == tab {
            if !pages.isEmpty { popAll() }
            return
        }
        // Leaving a tab drops its pages at once.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { pages.removeAll() }
        withAnimation(Motion.tab.rm) { tab = picked }
        entries[picked, default: 0] += 1
        Motion.after(0.14) { self.iconPlay[picked, default: 0] += 1 }
    }

    /// Plays the rise and draw of the current tab (at launch).
    func enter() {
        entries[tab, default: 0] += 1
        Motion.after(0.5) { self.iconPlay[self.tab, default: 0] += 1 }
    }

    // MARK: Pages

    func push(_ page: Page, from origin: CGPoint? = nil) {
        let start = origin ?? TouchPoint.last ?? CGPoint(x: 195, y: 430)
        TouchPoint.last = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { pages.append(PageEntry(page: page, origin: start)) }
        let id = pages.last?.id
        // A frame later, so the page exists before its circle opens.
        Task { @MainActor in
            withAnimation(Motion.flood.rm) {
                if let i = self.pages.firstIndex(where: { $0.id == id }) { self.pages[i].open = true }
            }
        }
    }

    /// Back folds the top page into where it came from.
    func back() {
        guard let i = pages.indices.last, pages[i].open else { return }
        let id = pages[i].id
        withAnimation(Motion.flood.rm) {
            pages[i].open = false
            dragBack = 0
        } completion: {
            self.pages.removeAll { $0.id == id }
        }
    }

    func popAll() {
        guard pages.count > 0 else { return }
        if pages.count > 1 {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { pages.removeFirst(pages.count - 1) }
        }
        back()
    }

    /// The page on top, if any.
    var top: Page? { pages.last(where: { $0.open })?.page ?? pages.last?.page }

    // MARK: Overlays

    func showToast(_ text: String) {
        let item = ToastItem(text: text)
        withAnimation(.curve(0.3, 1.5, 0.5, 1, 0.45).rm) { toast = item }
        UIAccessibility.post(notification: .announcement, argument: text)
        Motion.after(2.2, always: true) {
            if self.toast?.id == item.id {
                withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
            }
        }
    }

    /// The check-in slides up from the bottom.
    func openCheckIn(_ request: CheckInRequest) {
        withAnimation(.curve(0.2, 0.9, 0.2, 1, 0.55).rm) { checkIn = request }
    }

    /// Floods the screen gold from `origin` (window coordinates).
    func openAnswered(_ text: String, from origin: CGPoint) {
        answered = AnsweredFlood(text: text, origin: origin)
        Task { @MainActor in
            withAnimation(.curve(0.7, 0, 0.2, 1, 0.65).rm) { self.answered?.open = true }
        }
    }

    func closeAnswered() {
        withAnimation(.curve(0.7, 0, 0.2, 1, 0.65).rm) {
            answered?.open = false
        } completion: {
            self.answered = nil
        }
    }

    /// The destination tab's icon gives a little pop.
    func popIcon(_ t: RootTab) {
        iconPop[t, default: 0] += 1
    }

    // MARK: What the chrome looks like

    var barMode: BarMode {
        if answered?.open == true { return .gold }
        if let top { return top.style == .flood ? .flood : .paper }
        if tab == .prayer || (tab == .today && todayAllDone) { return .flood }
        return .paper
    }
}

// MARK: - Where the last touch landed

/// Pages flood out of what you tapped: the last touch-down, in window coordinates.
enum TouchPoint {
    @MainActor static var last: CGPoint?
}

/// Records every touch-down on the window without taking part in any gesture.
private final class TouchRecorder: UIGestureRecognizer, UIGestureRecognizerDelegate {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first, let window = view {
            let p = touch.location(in: window)
            MainActor.assumeIsolated { TouchPoint.last = p }
        }
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Put once in the root: installs the touch recorder on the window.
struct TouchTracker: UIViewRepresentable {
    func makeUIView(context: Context) -> TrackerView { TrackerView() }
    func updateUIView(_ uiView: TrackerView, context: Context) {}

    final class TrackerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchRecorder }) else { return }
            let recorder = TouchRecorder(target: nil, action: nil)
            recorder.cancelsTouchesInView = false
            recorder.delaysTouchesBegan = false
            recorder.delaysTouchesEnded = false
            recorder.delegate = recorder
            window.addGestureRecognizer(recorder)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
    }
}
