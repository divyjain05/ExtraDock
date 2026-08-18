import AppKit
import QuartzCore
import SwiftUI

final class DockPanelController: NSObject {
    private let panel: NSPanel
    private let hoverMonitor = EdgeHoverMonitor()
    private var apps: [DockApp]
    private var isExpanded = false

    private let edgeTriggerWidth: CGFloat = 6
    private let edgeTriggerHeight: CGFloat = 220
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
    }

    func stop() {
        hoverMonitor.stop()
        hide(animated: false)
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
        hosting.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        panel.contentView = hosting
        panel.setContentSize(NSSize(width: contentWidth, height: contentHeight))
        positionOffscreen()
    }

    private func targetScreen() -> NSScreen {
        NSScreen.main ?? NSScreen.screens[0]
    }

    private func hiddenOrigin() -> NSPoint {
        let screen = targetScreen().frame
        return NSPoint(x: screen.maxX, y: screen.minY + bottomInset)
    }

    private func visibleOrigin() -> NSPoint {
        let screen = targetScreen().frame
        let width = panel.frame.width
        return NSPoint(x: screen.maxX - width - 2, y: screen.minY + bottomInset)
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
        let screen = targetScreen().frame
        let inTriggerZone = (screen.maxX - location.x) <= edgeTriggerWidth
            && location.y >= screen.minY
            && location.y <= screen.minY + edgeTriggerHeight

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
