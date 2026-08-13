import Foundation
import UserNotifications

/// Notifications macOS à l'arrivée d'un mail sur une adresse suivie.
enum NotificationService {

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func postNewMail(address: String, from: String, subject: String, uid: UInt32) {
        let content = UNMutableNotificationContent()
        content.title = address
        content.subtitle = from
        content.body = subject
        content.sound = .default

        let request = UNNotificationRequest(identifier: "mail-\(uid)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
