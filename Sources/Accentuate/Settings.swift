import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    static var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static var assumeFrench: Bool {
        get { defaults.bool(forKey: "assumeFrench") }
        set { defaults.set(newValue, forKey: "assumeFrench") }
    }
}
