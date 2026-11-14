import AccentuateCore
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

    /// "auto", or the id of the language to always assume. (Used to be a French-only toggle.)
    static var language: String {
        get { defaults.string(forKey: "language") ?? (defaults.bool(forKey: "assumeFrench") ? "fr" : "auto") }
        set { set(newValue, forKey: "language") }
    }

    static var languageSelection: LanguageSelection {
        Language.withID(language).map { .fixed($0) } ?? .auto
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
