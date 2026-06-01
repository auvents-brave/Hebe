import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let highCountNotificationThresholdOptions: [Int] =
        Array(stride(from: 0, through: 100, by: 10)) + [200, 300, 400, 500]

    @Published var showMenuBarStats: Bool {
        didSet {
            set(showMenuBarStats, forKey: SettingsKeys.showMenuBarStats)
        }
    }
    /// Single shared flag for the Siri tip card (the phrase shown rotates, but
    /// dismissing the card hides it entirely until reset).
    @Published var showSiriTip: Bool {
        didSet {
            set(showSiriTip, forKey: SettingsKeys.showSiriTip)
        }
    }
    @Published var enableZeroCountNotification: Bool {
        didSet {
            set(enableZeroCountNotification, forKey: SettingsKeys.enableZeroCountNotification)
        }
    }
    @Published var highCountNotificationThreshold: Int {
        didSet {
            set(highCountNotificationThreshold, forKey: SettingsKeys.highCountNotificationThreshold)
        }
    }
    /// Whether posting a notification bounces the app's Dock icon (macOS).
    @Published var bounceDockOnNotification: Bool {
        didSet {
            set(bounceDockOnNotification, forKey: SettingsKeys.bounceDockOnNotification)
        }
    }

    private let store: NSUbiquitousKeyValueStore
    private let localDefaults: UserDefaults

    private init(
        store: NSUbiquitousKeyValueStore = .default,
        localDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.localDefaults = localDefaults
        store.synchronize()
        showMenuBarStats = Self.boolValue(
            forKey: SettingsKeys.showMenuBarStats,
            in: store,
            default: false
        )
        showSiriTip = Self.resolvedInitialValue(
            forKey: SettingsKeys.showSiriTip,
            default: true,
            store: store,
            localDefaults: localDefaults
        )
        enableZeroCountNotification = Self.boolValue(
            forKey: SettingsKeys.enableZeroCountNotification,
            in: store,
            default: false
        )
        highCountNotificationThreshold = Self.intValue(
            forKey: SettingsKeys.highCountNotificationThreshold,
            in: store,
            default: 0
        )
        bounceDockOnNotification = Self.boolValue(
            forKey: SettingsKeys.bounceDockOnNotification,
            in: store,
            default: true
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }

    @objc private func handleStoreChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        else { return }

        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.applyExternalChanges(keys: keys)
            }
            return
        }

        applyExternalChanges(keys: keys)
    }

    private func applyExternalChanges(keys: [String]) {
        if keys.contains(SettingsKeys.showMenuBarStats) {
            let newValue = boolValue(forKey: SettingsKeys.showMenuBarStats, default: true)
            if newValue != showMenuBarStats {
                showMenuBarStats = newValue
            }
        }
        if keys.contains(SettingsKeys.showSiriTip) {
            let newValue = boolValue(forKey: SettingsKeys.showSiriTip, default: true)
            if newValue != showSiriTip {
                showSiriTip = newValue
            }
        }
        if keys.contains(SettingsKeys.enableZeroCountNotification) {
            let newValue = boolValue(forKey: SettingsKeys.enableZeroCountNotification, default: true)
            if newValue != enableZeroCountNotification {
                enableZeroCountNotification = newValue
            }
        }
        if keys.contains(SettingsKeys.highCountNotificationThreshold) {
            let newValue = intValue(forKey: SettingsKeys.highCountNotificationThreshold, default: 500)
            if newValue != highCountNotificationThreshold {
                highCountNotificationThreshold = newValue
            }
        }
        if keys.contains(SettingsKeys.bounceDockOnNotification) {
            let newValue = boolValue(forKey: SettingsKeys.bounceDockOnNotification, default: true)
            if newValue != bounceDockOnNotification {
                bounceDockOnNotification = newValue
            }
        }
    }

    private func set(_ value: Bool, forKey key: String) {
        store.set(value, forKey: key)
        store.synchronize()
    }

    private func set(_ value: Int, forKey key: String) {
        store.set(value, forKey: key)
        store.synchronize()
    }

    private func boolValue(forKey key: String, default defaultValue: Bool) -> Bool {
        Self.boolValue(forKey: key, in: store, default: defaultValue)
    }

    private func intValue(forKey key: String, default defaultValue: Int) -> Int {
        Self.intValue(forKey: key, in: store, default: defaultValue)
    }

    private func resolvedInitialValue(forKey key: String, default defaultValue: Bool) -> Bool {
        Self.resolvedInitialValue(
            forKey: key,
            default: defaultValue,
            store: store,
            localDefaults: localDefaults
        )
    }

    private static func boolValue(
        forKey key: String,
        in store: NSUbiquitousKeyValueStore,
        default defaultValue: Bool
    ) -> Bool {
        guard let value = store.object(forKey: key) else { return defaultValue }
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        return defaultValue
    }

    private static func intValue(
        forKey key: String,
        in store: NSUbiquitousKeyValueStore,
        default defaultValue: Int
    ) -> Int {
        guard let value = store.object(forKey: key) else { return defaultValue }
        if let value = value as? Int { return value }
        if let number = value as? NSNumber { return number.intValue }
        if let value = value as? String, let intValue = Int(value) { return intValue }
        return defaultValue
    }

    private static func resolvedInitialValue(
        forKey key: String,
        default defaultValue: Bool,
        store: NSUbiquitousKeyValueStore,
        localDefaults: UserDefaults
    ) -> Bool {
        if store.object(forKey: key) != nil {
            return boolValue(forKey: key, in: store, default: defaultValue)
        }
        if let localValue = localDefaults.object(forKey: key) as? Bool {
            store.set(localValue, forKey: key)
            store.synchronize()
            return localValue
        }
        return defaultValue
    }
}

enum SettingsKeys {
    static let showMenuBarStats = "showMenuBarStats"
    static let showSiriTip = "showSiriTip"
    static let enableZeroCountNotification = "enableZeroCountNotification"
    static let highCountNotificationThreshold = "highCountNotificationThreshold"
    static let bounceDockOnNotification = "bounceDockOnNotification"
}
