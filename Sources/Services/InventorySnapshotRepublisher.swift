import Foundation
import UserNotifications

#if canImport(WidgetKit)
    import WidgetKit
#endif
#if os(macOS)
    import AppKit
#endif

@MainActor
enum InventorySnapshotRepublisher {
    static func publish(snapshot: InventorySnapshot) {
        InventorySnapshotStore.save(snapshot)
        InventoryCountNotificationPublisher.evaluate(snapshot: snapshot)

        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.widgetKind)
        #endif
    }
}

@MainActor
enum InventoryCountNotificationPublisher {
    private static let zeroNotificationIdentifier = "inventory.things.zero"
    private static let highCountNotificationIdentifier = "inventory.things.highcount"
    private static let lastTotalCountKey = "inventory.things.notification.lastTotalCount"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupIdentifier) ?? .standard
    }

    static func evaluate(snapshot: InventorySnapshot) {
        let currentTotal = snapshot.totalThingCount
        let previousTotal = defaults.object(forKey: lastTotalCountKey) as? Int
        defaults.set(currentTotal, forKey: lastTotalCountKey)

        guard let previousTotal else { return }

        if SettingsStore.shared.enableZeroCountNotification, previousTotal != 0, currentTotal == 0 {
            scheduleNotification(
                identifier: zeroNotificationIdentifier,
                title: String(localized: "Inventory is empty"),
                body: String(localized: "Your total things count is now zero.")
            )
        }

        let threshold = SettingsStore.shared.highCountNotificationThreshold
        guard threshold > 0 else { return }

        if previousTotal < threshold, currentTotal >= threshold {
            scheduleNotification(
                identifier: highCountNotificationIdentifier,
                title: String(localized: "Inventory threshold reached"),
                body: L10n.Notifications.thresholdReachedBody(
                    currentTotal: currentTotal,
                    threshold: threshold
                )
            )
        }
    }

    private static func scheduleNotification(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        #if !os(tvOS)
            content.title = title
            content.body = body
            content.sound = .default
        #endif

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)

        #if os(macOS)
            // Bounce the Dock icon (until the app is activated) when it isn't
            // frontmost, if enabled.
            if SettingsStore.shared.bounceDockOnNotification {
                NSApplication.shared.requestUserAttention(.criticalRequest)
            }
        #endif
    }
}
