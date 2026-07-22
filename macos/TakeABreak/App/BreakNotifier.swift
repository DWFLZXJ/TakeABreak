import Foundation
import UserNotifications

enum BreakNotifier {
    static func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func notifyBreakStarted(message: String, todoCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            guard ok else { return }

            let content = UNMutableNotificationContent()
            content.title = "该休息了"
            var body = message
            if todoCount > 0 {
                body += " · \(todoCount) 条待办提醒"
            }
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "takeabreak.break.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request, withCompletionHandler: nil)
        }
    }
}
