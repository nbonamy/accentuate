import AccentuateCore
import AppKit
import ServiceManagement

struct ExcludedApp: Identifiable, Equatable {
    let id: String // bundle identifier
    var name: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
    var icon: NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

final class SettingsModel: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Accentuate: cannot change login item: \(error)")
                DispatchQueue.main.async { self.launchAtLogin = SMAppService.mainApp.status == .enabled }
            }
        }
    }
    @Published var showMenuBarIcon: Bool { didSet { Settings.showMenuBarIcon = showMenuBarIcon } }
    @Published var enabled: Bool { didSet { Settings.enabled = enabled } }
    @Published var language: String { didSet { Settings.language = language } }
    @Published var sensitivity: Sensitivity { didSet { Settings.sensitivity = sensitivity } }
    @Published var excludedApps: [ExcludedApp] { didSet { Settings.excludedApps = excludedApps.map(\.id) } }
    let languages = Language.available
    @Published var accessibilityGranted = AXIsProcessTrusted()

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showMenuBarIcon = Settings.showMenuBarIcon
        enabled = Settings.enabled
        language = Settings.language
        sensitivity = Settings.sensitivity
        excludedApps = Settings.excludedApps.map(ExcludedApp.init)
    }

    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        accessibilityGranted = AXIsProcessTrusted()
    }

    func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier, !excludedApps.contains(where: { $0.id == id }) else { continue }
            excludedApps.append(ExcludedApp(id: id))
        }
    }

    func remove(_ app: ExcludedApp) {
        excludedApps.removeAll { $0 == app }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
