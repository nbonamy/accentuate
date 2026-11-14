import AppKit
import ApplicationServices
import AccentuateCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var tapController: EventTapController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let suggester = AccentSuggester(spellChecker: SystemSpellChecker(), frequencies: (try? WordFrequencies.bundled()) ?? WordFrequencies(tsv: ""))
        tapController = EventTapController(engine: CorrectionEngine(suggester: suggester, detector: NLLanguageDetector()))

        statusItem.button?.image = MenuBarIcon.make()
        statusItem.menu = {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }()
        updateIcon()
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateIcon()
        }
        // Started by hand with no menu bar icon: show the settings, or nothing would seem to happen.
        if !Settings.showMenuBarIcon && !launchedAtLogin() { SettingsWindowController.shared.show() }

        // Ask once (shows the system prompt), then poll until the permission is granted.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.tapController?.installIfTrusted()
        }
        tapController?.installIfTrusted()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    private func launchedAtLogin() -> Bool {
        NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabled = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = Settings.enabled ? .on : .off
        menu.addItem(enabled)

        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu()
        menu.addItem(languageItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))

        if !AXIsProcessTrusted() {
            menu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Accentuate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func toggleEnabled() {
        Settings.enabled.toggle()
        updateIcon()
    }

    private func languageMenu() -> NSMenu {
        let menu = NSMenu()
        let choices = [("auto", "Auto-detect")] + Language.available.map { ($0.id, $0.name) }
        for (id, name) in choices {
            let item = NSMenuItem(title: name, action: #selector(chooseLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.state = Settings.language == id ? .on : .off
            menu.addItem(item)
            if id == "auto" { menu.addItem(.separator()) }
        }
        return menu
    }

    @objc private func chooseLanguage(_ item: NSMenuItem) {
        Settings.language = item.representedObject as? String ?? "auto"
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func updateIcon() {
        statusItem.isVisible = Settings.showMenuBarIcon
        statusItem.button?.appearsDisabled = !Settings.enabled
    }
}
