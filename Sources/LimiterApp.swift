import SwiftUI
import AppKit
import ServiceManagement

@main
struct LimiterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = UsageMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        updateIcon(percent: 0)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(monitor: monitor)
        )

        monitor.onUpdate = { [weak self] maxPercent in
            self?.updateIcon(percent: maxPercent)
        }

        monitor.startMonitoring()
    }

    private func updateIcon(percent: Int) {
        guard let button = statusItem.button else { return }

        let color: NSColor
        if percent < 50 {
            color = .systemGreen
        } else if percent < 80 {
            color = .systemYellow
        } else {
            color = .systemRed
        }

        let image = NSImage(
            systemSymbolName: "circle.fill",
            accessibilityDescription: "Limiter"
        )
        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        button.image = image?.withSymbolConfiguration(config)
        button.image?.isTemplate = false
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
