import SwiftUI
import UserNotifications

// Owns the store so notification actions can reach it, even from the lock screen.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = Store()

    func application(_ app: UIApplication, didFinishLaunchingWithOptions opts: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        let take = UNNotificationAction(identifier: "TAKE", title: "I'll take it", options: [])
        let pass = UNNotificationAction(identifier: "PASS", title: "Not this time", options: [])
        let open = UNNotificationAction(identifier: "OPEN", title: "Open in Shoal", options: [.foreground])
        let thank = UNNotificationAction(identifier: "THANK", title: "Say thanks", options: [])
        c.setNotificationCategories([
            UNNotificationCategory(identifier: "ASK", actions: [take, pass, open], intentIdentifiers: []),
            UNNotificationCategory(identifier: "DONE", actions: [thank, open], intentIdentifiers: []),
        ])
        return true
    }

    nonisolated func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ c: UNUserNotificationCenter, didReceive r: UNNotificationResponse) async {
        let action = r.actionIdentifier
        let id = r.notification.request.content.userInfo["task"] as? String ?? ""
        await MainActor.run { self.handle(action, id) }
    }

    private func handle(_ action: String, _ id: String) {
        switch action {
        case "TAKE": store.take(id); store.syncWidgets()
        case "PASS": store.say("Okay. The family will ask someone else.")
        case "THANK":
            store.thanked.insert(id)
            store.say("Sent \(store.name(store.task(id)?.who)) a thank-you")
        default:
            store.onboarded = true
            store.tab = 0
            store.paths[0] = [.task(id)]
        }
    }
}

enum Notify {
    // Asks for permission the first time, then sends a sample a few seconds later.
    @MainActor static func send(_ kind: String, store: Store, after: Double = 5) async -> Bool {
        let c = UNUserNotificationCenter.current()
        guard (try? await c.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return false }
        let content = UNMutableNotificationContent()
        content.sound = .default
        if kind == "ask" {
            guard let t = store.tasks.first(where: { $0.who == nil && !$0.done }) else { return false }
            content.title = "Can someone take this?"
            content.body = "\(t.n) · \(t.dueLabel)"
            content.categoryIdentifier = "ASK"
            content.userInfo = ["task": t.id]
        } else {
            guard let t = store.tasks.first(where: { $0.done && $0.who != "you" && $0.who != nil }) else { return false }
            content.title = "\(store.name(t.who)) finished a task"
            content.body = "\(t.n). Say thanks?"
            content.categoryIdentifier = "DONE"
            content.userInfo = ["task": t.id]
        }
        let req = UNNotificationRequest(identifier: kind + UUID().uuidString, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false))
        return (try? await c.add(req)) != nil
    }
}
