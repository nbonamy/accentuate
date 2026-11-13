import Foundation

extension Notification.Name {
    /// Posted when the user changes one of our settings (not for any other UserDefaults write).
    static let settingsChanged = Notification.Name("AccentuateSettingsChanged")
}

enum Settings {
    private static let defaults = UserDefaults.standard

    private static func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    static var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { set(newValue, forKey: "enabled") }
    }

    static var assumeFrench: Bool {
        get { defaults.bool(forKey: "assumeFrench") }
        set { set(newValue, forKey: "assumeFrench") }
    }

    static var showMenuBarIcon: Bool {
        get { defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true }
        set { set(newValue, forKey: "showMenuBarIcon") }
    }

    /// Bundle identifiers of the apps where Accentuate stays out of the way.
    static var excludedApps: [String] {
        get { defaults.stringArray(forKey: "excludedApps") ?? [] }
        set { set(newValue, forKey: "excludedApps") }
    }
}
