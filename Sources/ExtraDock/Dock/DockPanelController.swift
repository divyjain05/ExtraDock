import AppKit
import QuartzCore
import SwiftUI

final class DockPanelController: NSObject {
    private let panel: NSPanel
    private let hoverMonitor = EdgeHoverMonitor()
    private var apps: [DockApp]
    private var isExpanded = false

    // Cached on-screen frame of this app's own Dock icon, refreshed
    // periodically since the Dock reflows icon positions as other apps
    // launch/quit. nil until Accessibility permission is granted and the
    // Dock has registered the icon.
    private var dockIconFrame: CGRect?
    private var iconRefreshTimer: Timer?

    // Fallback trigger for when the Dock icon's frame isn't known yet
    // (permission not granted, or the Dock hasn't registered it yet).
    private let edgeTriggerWidth: CGFloat = 6
    private let edgeTriggerHeight: CGFloat = 320

    private let iconSize: CGFloat = 56
    private let panelPadding: CGFloat = 16
    private let iconSpacing: CGFloat = 14
    private let bottomInset: CGFloat = 4

    init(apps: [DockApp]) {
        self.apps = apps
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = DockPanelController.levelAboveDock()
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        super.init()

        rebuildContent()
        hoverMonitor.onMouseMoved = { [weak self] location in
            self?.handleMouseMoved(location)
        }
    }

    // NSWindow.Level has no public "dock" case. 20 is kCGDockWindowLevel from
    // CoreGraphics/CGWindowLevel.h (also exposed, deprecated, as NSDockWindowLevel).
    // Sitting one above it renders this panel on top of the real Dock.
    private static func levelAboveDock() -> NSWindow.Level {
        NSWindow.Level(rawValue: 20 + 1)
    }

    func start() {
        hoverMonitor.start()

        refreshDockIconFrame()
        // The Dock can take a moment to register a freshly-launched app's icon.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshDockIconFrame()
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshDockIconFrame()
        }
        RunLoop.main.add(timer, forMode: .common)
        iconRefreshTimer = timer

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(refreshDockIconFrame), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(refreshDockIconFrame), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    func stop() {
        hoverMonitor.stop()
        iconRefreshTimer?.invalidate()
        iconRefreshTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hide(animated: false)
    }

    @objc private func refreshDockIconFrame() {
        let displayName = NSRunningApplication.current.localizedName ?? "ExtraDock"
        dockIconFrame = DockIconLocator.currentIconFrame(displayName: displayName)
    }

    func update(apps: [DockApp]) {
        self.apps = apps
        rebuildContent()
    }

    /// Manual toggle for the status-bar menu, independent of hover — useful
    /// both as a fallback trigger and for testing without moving the mouse.
    func toggleForTesting() {
        isExpanded ? hide(animated: true) : show(animated: true)
    }

    private func rebuildContent() {
        let iconsWidth = apps.isEmpty ? 220 : CGFloat(apps.count) * iconSize + CGFloat(max(apps.count - 1, 0)) * iconSpacing
        let contentWidth = iconsWidth + panelPadding * 2
        let contentHeight = iconSize + panelPadding * 2

        let view = DockView(apps: apps, iconSize: iconSize) { [weak self] app in
            self?.launch(app)
        }
        let hosting = NSHostingView(rootView: view)
        let bounds = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]

        let dropView = DockDropView(frame: bounds)
        dropView.addSubview(hosting)
        dropView.onDropApps = { [weak self] urls in
            self?.handleDrop(urls)
        }

        panel.contentView = dropView
        panel.setContentSize(NSSize(width: contentWidth, height: contentHeight))
        positionOffscreen()
    }

    private func handleDrop(_ urls: [URL]) {
        for url in urls {
            DockStore.shared.addApp(at: url)
        }
        update(apps: DockStore.shared.load())
    }

    private func targetScreen() -> NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    // Where the panel settles horizontally: centered above this app's own
    // Dock icon when we know where that is, otherwise centered on screen
    // (matching the Dock's own default bottom-centered position) as a
    // reasonable fallback.
    private func targetX(forWidth width: CGFloat) -> CGFloat {
        let screen = targetScreen().frame
        if let iconFrame = dockIconFrame {
            let clampedMidX = min(max(iconFrame.midX, screen.minX + width / 2), screen.maxX - width / 2)
            return clampedMidX - width / 2
        }
        return screen.midX - width / 2
    }

    private func hiddenOrigin() -> NSPoint {
        let screen = targetScreen().frame
        return NSPoint(x: targetX(forWidth: panel.frame.width), y: screen.minY - panel.frame.height)
    }

    private func visibleOrigin() -> NSPoint {
        let screen = targetScreen().frame
        return NSPoint(x: targetX(forWidth: panel.frame.width), y: screen.minY + bottomInset)
    }

    private func positionOffscreen() {
        panel.setFrameOrigin(hiddenOrigin())
    }

    private func show(animated: Bool) {
        guard !isExpanded else { return }
        isExpanded = true
        panel.setFrameOrigin(hiddenOrigin())
        panel.orderFrontRegardless()
        let target = visibleOrigin()
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrameOrigin(target)
            }
        } else {
            panel.setFrameOrigin(target)
        }
    }

    private func hide(animated: Bool) {
        guard isExpanded else { return }
        isExpanded = false
        let target = hiddenOrigin()
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrameOrigin(target)
            }, completionHandler: { [weak self] in
                self?.panel.orderOut(nil)
            })
        } else {
            panel.setFrameOrigin(target)
            panel.orderOut(nil)
        }
    }

    private func handleMouseMoved(_ location: NSPoint) {
        let inTriggerZone: Bool
        if let iconFrame = dockIconFrame {
            inTriggerZone = iconFrame.insetBy(dx: -6, dy: -6).contains(location)
        } else {
            // No Dock icon frame yet (permission not granted, or the Dock
            // hasn't registered it). Fall back to a right-edge hover zone so
            // the app still works, just not anchored to the icon.
            let screen = targetScreen().frame
            inTriggerZone = (screen.maxX - location.x) <= edgeTriggerWidth
                && location.y >= screen.minY
                && location.y <= screen.minY + edgeTriggerHeight
        }

        let inPanel = isExpanded && panel.frame.insetBy(dx: -4, dy: -4).contains(location)

        if inTriggerZone || inPanel {
            show(animated: true)
        } else {
            hide(animated: true)
        }
    }

    private func launch(_ app: DockApp) {
        guard let url = app.resolvedURL() else { return }
        NSWorkspace.shared.open(url)
    }
}
