import Foundation
import UserNotifications

/// Local-only reminders. No server, no tokens, nothing leaves the device.
enum Reminders {
    private static let morningId = "athar.reminder.morning"
    private static let eveningId = "athar.reminder.evening"
    private static let athanPrefix = "athar.athan."

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningId, eveningId])
        await rescheduleAthan(store: store)
        guard store.remindersEnabled else { return }

        await add(id: morningId,
                  title: "أذكار الصباح",
                  body: "﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾ — دقيقتان تكفيك اليوم كله.",
                  minutes: store.morningReminderMinutes)

        await add(id: eveningId,
                  title: "أذكار المساء",
                  body: "حصّن يومك قبل أن يغيب — أذكار المساء بانتظارك.",
                  minutes: store.eveningReminderMinutes)
    }

    /// Schedules the next few days of prayer alerts. iOS caps pending local
    /// notifications at 64, so we schedule 7 days x 5 prayers and refresh on launch.
    static func rescheduleAthan(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(athanPrefix) }
        )
        guard store.athanAlerts else { return }

        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = store.prayerTimes(for: day) else { continue }

            for entry in times.ordered where entry.prayer.isPrayer {
                guard entry.date > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "حان وقت \(entry.prayer.title)"
                content.body = "\(store.placeName) — أقم الصلاة، ولا تنسَ أذكار ما بعدها."
                content.sound = .default

                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
                let request = UNNotificationRequest(
                    identifier: "\(athanPrefix)\(dayOffset).\(entry.prayer.rawValue)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    private static func add(id: String, title: String, body: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
