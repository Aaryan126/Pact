import Foundation
import UserNotifications

@MainActor
protocol SessionCompletionNotifying {
    func notifySessionCompleted(targetDuration: TimeInterval?)
}

struct UserNotificationSessionCompletionNotifier: SessionCompletionNotifying {
    func notifySessionCompleted(targetDuration: TimeInterval?) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let isAllowed: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAllowed = true
            case .notDetermined:
                isAllowed = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
            case .denied:
                isAllowed = false
            @unknown default:
                isAllowed = false
            }

            guard isAllowed else { return }

            let content = UNMutableNotificationContent()
            content.title = "FocusMirror session complete"
            if let targetDuration {
                content.body = "Your \(formatMinutes(targetDuration)) session is ready to review."
            } else {
                content.body = "Your session is ready to review."
            }
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "focusmirror.session.complete.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
