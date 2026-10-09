import Foundation
import SwiftData
import UserNotifications

/// Local notifications at 9:00 for due tasks, partner follow-ups, partner birthdays and expiring documents.
/// Rebuilt after every sync and when the app opens, so they always match your data.
enum Reminders {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    private struct Item {
        var date: Date
        var id: String
        var title: String
        var body: String
    }

    @MainActor
    static func refresh(_ ctx: ModelContext) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        let now = Date.now
        var items: [Item] = []

        for t in Store.all(Todo.self, ctx) where !t.isDone {
            // An exact reminder time wins; otherwise 9:00 on the due day.
            if let at = t.remindAt, at > now {
                items.append(Item(date: at, id: "task-\(t.id)", title: t.displayTitle, body: t.areaValue.title))
            } else if let due = t.dueDate, let at = nineAM(due), at > now {
                items.append(Item(date: at, id: "task-\(t.id)", title: "Today: \(t.displayTitle)", body: t.areaValue.title))
            }
        }
        for p in Store.all(Partner.self, ctx) {
            if p.stageValue.isOpen, let d = p.nextFollowUp, let at = nineAM(d), at > now {
                let step = p.nextStep.isEmpty ? "Follow up" : p.nextStep
                items.append(Item(date: at, id: "partner-\(p.id)", title: "\(step): \(p.displayTitle)", body: "Support partner"))
            }
            if p.stageValue.countsAsSupport, let b = p.birthday, let next = nextBirthday(b, after: now), let at = nineAM(next) {
                items.append(Item(date: at, id: "bday-\(p.id)", title: "\(p.firstName) has a birthday today",
                                  body: "A good day to send a message and say thanks."))
            }
        }
        for d in Store.all(Document.self, ctx) {
            guard let exp = d.expiresAt else { continue }
            for days in [90, 30] {
                if let warn = Calendar.current.date(byAdding: .day, value: -days, to: exp), let at = nineAM(warn), at > now {
                    items.append(Item(date: at, id: "doc-\(d.id)-\(days)", title: "\(d.displayTitle) expires in \(days) days",
                                      body: exp.formatted(date: .long, time: .omitted)))
                }
            }
        }

        center.removeAllPendingNotificationRequests()
        // iOS keeps at most 64 pending; schedule the nearest ones.
        for item in items.sorted(by: { $0.date < $1.date }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    private static func nineAM(_ day: Date) -> Date? {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)
    }

    private static func nextBirthday(_ birthday: Date, after now: Date) -> Date? {
        let cal = Calendar.current
        let md = cal.dateComponents([.month, .day], from: birthday)
        return cal.nextDate(after: cal.startOfDay(for: now).addingTimeInterval(-1), matching: md, matchingPolicy: .nextTime)
    }
}
