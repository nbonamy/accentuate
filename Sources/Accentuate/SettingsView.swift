import AccentuateCore
import SwiftUI

// MARK: Glass

/// Liquid Glass on macOS 26, a plain material before.
private struct GlassBackground: ViewModifier {
    let shape: AnyShape

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

private extension View {
    func glass<S: Shape>(in shape: S) -> some View { modifier(GlassBackground(shape: AnyShape(shape))) }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .glass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
        .frame(height: 44)
    }
}

// MARK: View

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                Card {
                    ToggleRow(title: "Correct accents as I type", isOn: $model.enabled)
                    Divider()
                    languageRow
                }
                Card {
                    ToggleRow(title: "Start at login", isOn: $model.launchAtLogin)
                    Divider()
                    ToggleRow(title: "Show in menu bar", isOn: $model.showMenuBarIcon)
                }
                excludedApps
                permission
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .frame(width: 440, height: 600)
        .onReceive(timer) { _ in model.refresh() }
    }

    private var languageRow: some View {
        HStack {
            Text("Language")
            Spacer()
            Picker("Language", selection: $model.language) {
                Text("Auto-detect").tag("auto")
                Divider()
                ForEach(model.languages) { Text($0.name).tag($0.id) }
            }
            .labelsHidden()
            .fixedSize()
        }
        .frame(height: 44)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            Text("Accentuate").font(.title2.weight(.semibold))
            HStack(spacing: 6) {
                Text("Version \(version)")
                Text("·")
                Link("GitHub", destination: URL(string: "https://github.com/nbonamy/accentuate")!)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var excludedApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Don't correct in")
                .font(.headline)
                .padding(.leading, 6)
            Card {
                ForEach(model.excludedApps) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon).resizable().frame(width: 24, height: 24)
                        Text(app.name)
                        Spacer()
                        Button { model.remove(app) } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 44)
                    Divider()
                }
                Button { model.addExcludedApp() } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add App…")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: 44)
            }
        }
    }

    private var permission: some View {
        HStack(spacing: 10) {
            if model.accessibilityGranted {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Open Settings") { model.openAccessibilitySettings() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glass(in: Capsule())
    }
}

// MARK: Window

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private let model = SettingsModel()

    func show() {
        if window == nil { window = makeWindow() }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: SettingsView(model: model))
        hosting.sizingOptions = []
        let size = NSSize(width: 440, height: 600)

        let background: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            // A tint of the window color keeps the glass but lets less of the background through.
            glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6)
            glass.contentView = hosting
            background = glass
        } else {
            let blur = NSVisualEffectView()
            blur.material = .underWindowBackground
            blur.blendingMode = .behindWindow
            blur.state = .active
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.autoresizingMask = [.width, .height]
            blur.addSubview(hosting)
            background = blur
        }

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Accentuate"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentView = background
        window.center()
        return window
    }
}
