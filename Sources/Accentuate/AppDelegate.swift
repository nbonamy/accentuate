import AppKit
import ApplicationServices
import AccentuateCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var tapController: EventTapController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let suggester = AccentSuggester(spellChecker: SystemSpellChecker(), frequencies: try WordFrequencies.bundled())
            let engine = CorrectionEngine(suggester: suggester, detector: NLLanguageDetector())
            tapController = EventTapController(engine: engine)
        } catch {
            NSLog("Accentuate: cannot load dictionary: \(error)")
        }

        statusItem.button?.title = "é"
        statusItem.menu = {
            let menu = NSMenu()
            menu.delegate = self
            return menu
        }()
        updateIcon()

        // Ask once (shows the system prompt), then poll until the permission is granted.
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.tapController?.installIfTrusted()
        }
        tapController?.installIfTrusted()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabled = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = Settings.enabled ? .on : .off
        menu.addItem(enabled)

        let french = NSMenuItem(title: "Assume French", action: #selector(toggleAssumeFrench), keyEquivalent: "")
        french.state = Settings.assumeFrench ? .on : .off
        menu.addItem(french)

        menu.addItem(.separator())

        if AXIsProcessTrusted() {
            let status = NSMenuItem(title: "Accessibility: allowed", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
        } else {
            menu.addItem(NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Accentuate", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
    }

    @objc private func toggleEnabled() {
        Settings.enabled.toggle()
        updateIcon()
    }

    @objc private func toggleAssumeFrench() {
        Settings.assumeFrench.toggle()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func updateIcon() {
        statusItem.button?.appearsDisabled = !Settings.enabled
    }
}
