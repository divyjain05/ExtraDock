import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dockPanelController: DockPanelController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AccessibilityPermission.requestIfNeeded()

        let apps = DockStore.shared.load()
        let controller = DockPanelController(apps: apps)
        controller.start()
        dockPanelController = controller

        setUpStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dockPanelController?.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "ExtraDock")

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Extra Dock", action: #selector(togglePanel), target: self)
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), target: self)
        if !AccessibilityPermission.isGranted {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), target: self)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ExtraDock", action: #selector(quit), target: self)

        item.menu = menu
        statusItem = item
    }

    @objc private func togglePanel() {
        dockPanelController?.toggleForTesting()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController { [weak self] in
                self?.dockPanelController?.update(apps: DockStore.shared.load())
            }
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private extension NSMenu {
    func addItem(withTitle title: String, action: Selector, target: AnyObject) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        addItem(item)
    }
}
