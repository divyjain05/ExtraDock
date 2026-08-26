import AppKit
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

    // While the Size slider in Settings is being dragged, the panel is forced
    // visible so the change is seen live, and the hover-hide logic is suppressed
    // so it doesn't tuck away between ticks. It auto-hides shortly after the
    // last adjustment.
    private var isPreviewingSize = false
    private var sizePreviewHideWorkItem: DispatchWorkItem?

    // The panel is shared across all Spaces (.canJoinAllSpaces), so a switch
    // between desktops must not leave it lingering or flashing. On an active-
    // Space change the panel is force-hidden and hover-driven re-show is
    // suppressed until this deadline, letting the transition's stray mouseMoved
    // events settle before the cursor is trusted again.
    private var spaceChangeSuppressUntil: Date?

    // Cached Dock magnification settings. Read from com.apple.dock so the
    // trigger zone and panel anchor can account for how much a hovered icon
    // grows. Refreshed on the same cadence as the icon frame.
    private struct DockMagnification {
        let enabled: Bool
        let restingTile: CGFloat
        let largeTile: CGFloat
        // On-screen height an icon can occupy (magnified when enabled).
        var maxTile: CGFloat { enabled ? max(restingTile, largeTile) : restingTile }
    }
    private var magnification = DockMagnification(enabled: false, restingTile: 48, largeTile: 128)

    // Fallback trigger for when the Dock icon's frame isn't known yet
    // (permission not granted, or the Dock hasn't registered it yet).
    private let edgeTriggerWidth: CGFloat = 6
    private let edgeTriggerHeight: CGFloat = 320

    private var iconSize: CGFloat = AppPreferences.iconSize
    private let panelPadding: CGFloat = 16
    private let iconSpacing: CGFloat = 14

    // Full size of the panel once expanded. Held separately from panel.frame
    // because the collapsed (hidden) state also varies panel.frame's height —
    // see collapsedFrame()/expandedFrame().
    private var contentSize: NSSize = .zero

    init(apps: [DockApp]) {
        self.apps = apps
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.styleMask.remove(.resizable)   // no edge-resize cursors on the panel
        panel.level = DockPanelController.levelAboveDock()
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        // If the panel ever becomes key (e.g. during a drag-drop), it is then
        // the app's key window; accepting mouse-moved events keeps the local
        // hover monitor fed while ExtraDock is frontmost.
        panel.acceptsMouseMovedEvents = true

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
        center.addObserver(self, selector: #selector(activeSpaceDidChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    // On a desktop switch, tuck the panel away immediately (no animation, so it
    // can't be caught mid-slide on the outgoing Space) and ignore hover for a
    // short window while the transition's stray mouseMoved events settle. Also
    // cancels any Size-preview hold, which otherwise pins the panel visible.
    @objc private func activeSpaceDidChange() {
        isPreviewingSize = false
        sizePreviewHideWorkItem?.cancel()
        spaceChangeSuppressUntil = Date().addingTimeInterval(0.4)
        hide(animated: false)
    }

    func stop() {
        hoverMonitor.stop()
        iconRefreshTimer?.invalidate()
        iconRefreshTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hide(animated: false)
    }

    @objc private func refreshDockIconFrame() {
        magnification = readDockMagnification()

        // With magnification on, an icon's frame changes continuously as the
        // cursor sweeps the Dock, so a sample taken then is distorted (shifted
        // midX from growing neighbors, taller maxY). Cached as the "resting"
        // anchor it misaligns the panel. Skip sampling while the cursor is in
        // the band — including the very first sample (dockIconFrame still nil),
        // otherwise launching with the cursor over the Dock caches a magnified
        // frame. Only gate on magnification: with it off the frame is stable
        // regardless of cursor position, so sample immediately.
        if magnification.enabled && isCursorInDockBand(NSEvent.mouseLocation) { return }

        let displayName = NSRunningApplication.current.localizedName ?? "ExtraDock"
        dockIconFrame = DockIconLocator.currentIconFrame(displayName: displayName)
        NSLog("ExtraDock: axGranted=\(AccessibilityPermission.isGranted) refreshDockIconFrame -> \(String(describing: dockIconFrame))")
    }

    private func readDockMagnification() -> DockMagnification {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let enabled = defaults?.bool(forKey: "magnification") ?? false
        let tile = CGFloat(defaults?.double(forKey: "tilesize") ?? 0)
        let large = CGFloat(defaults?.double(forKey: "largesize") ?? 0)
        return DockMagnification(
            enabled: enabled,
            restingTile: tile > 0 ? tile : 48,
            largeTile: large > 0 ? large : 128
        )
    }

    // True when the cursor is down in the Dock's magnification band (near the
    // bottom of the target screen), where icons are actively growing/reflowing.
    private func isCursorInDockBand(_ location: NSPoint) -> Bool {
        let screen = targetScreen().frame
        let bandHeight = magnification.maxTile + 60
        return location.y >= screen.minY && location.y <= screen.minY + bandHeight
    }

    func update(apps: [DockApp]) {
        self.apps = apps
        rebuildContent()
    }

    /// Live-applies a new icon size from Settings. Rebuilds the panel at the new
    /// dimensions and forces it visible so the change is seen as it happens, then
    /// tucks it away shortly after adjustments stop.
    func setIconSize(_ size: CGFloat) {
        iconSize = size
        rebuildContent()
        isPreviewingSize = true
        showForSizePreview()
        scheduleSizePreviewHide()
    }

    // Like show(), but never animates (snappy live feedback) and always pins the
    // panel to the freshly-rebuilt expanded frame, even when already visible —
    // rebuildContent() leaves it collapsed, so this must set the frame each tick.
    private func showForSizePreview() {
        let wasExpanded = isExpanded
        isExpanded = true
        if !wasExpanded {
            panel.setFrame(collapsedFrame(), display: false)
            panel.orderFrontRegardless()
        }
        panel.setFrame(expandedFrame(), display: true)
    }

    private func scheduleSizePreviewHide() {
        sizePreviewHideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isPreviewingSize = false
            self.hide(animated: true)
        }
        sizePreviewHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
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

        let view = DockView(
            apps: apps,
            iconSize: iconSize,
            spacing: iconSpacing,
            onLaunch: { [weak self] app in self?.launch(app) },
            onReorder: { [weak self] newOrder in self?.persistReorder(newOrder) }
        )
        let hosting = CursorForcingHostingView(rootView: view)
        let bounds = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]

        let dropView = DockDropView(frame: bounds)
        dropView.addSubview(hosting)
        dropView.onDropApps = { [weak self] urls in
            self?.handleDrop(urls)
        }

        contentSize = NSSize(width: contentWidth, height: contentHeight)
        panel.contentView = dropView
        panel.setContentSize(contentSize)
        positionOffscreen()
    }

    private func handleDrop(_ urls: [URL]) {
        for url in urls {
            DockStore.shared.addApp(at: url)
        }
        update(apps: DockStore.shared.load())
    }

    // NSScreen.main is nil here (this panel deliberately never becomes key),
    // and NSScreen.screens[0] is not reliably the primary/menu-bar display on
    // multi-monitor setups. Prefer whichever screen actually contains the
    // Dock icon; fall back to the screen at global origin (0,0), which is
    // always the primary display, regardless of array ordering.
    private func targetScreen() -> NSScreen {
        if let iconFrame = dockIconFrame,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: iconFrame.midX, y: iconFrame.midY)) }) {
            return screen
        }
        return NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main ?? NSScreen.screens[0]
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

    // Both frames share the same bottom edge: the top of the Dock icon
    // itself. Only the height animates (1pt -> full), so the panel grows
    // straight up from a fixed baseline sitting right on top of the icon —
    // reads as rising directly out of it, rather than sliding up from
    // somewhere else on screen.
    private func anchorY() -> CGFloat {
        // Anchor flush to the *resting* Dock icon top. dockIconFrame is captured
        // while the cursor is away from the Dock (see refreshDockIconFrame), so
        // maxY is the resting top regardless of current magnification. The panel
        // sits one window level above the Dock, so a magnified icon simply grows
        // *behind* it — anchoring higher (to the magnified top) would instead
        // leave a visible gap once the Dock de-magnifies as the cursor moves up
        // into the panel.
        dockIconFrame?.maxY ?? targetScreen().frame.minY
    }

    private func expandedFrame() -> NSRect {
        let origin = NSPoint(x: targetX(forWidth: contentSize.width), y: anchorY())
        return NSRect(origin: origin, size: contentSize)
    }

    private func collapsedFrame() -> NSRect {
        let origin = NSPoint(x: targetX(forWidth: contentSize.width), y: anchorY())
        return NSRect(origin: origin, size: NSSize(width: contentSize.width, height: 1))
    }

    private func positionOffscreen() {
        panel.setFrame(collapsedFrame(), display: false)
    }

    // Uses NSWindow.setFrame(_:display:animate:) rather than
    // NSAnimationContext + animator().setFrameOrigin(): the latter's
    // completion handler fired instantly with the frame unchanged for this
    // nonactivating panel — it wasn't actually animating.
    private func show(animated: Bool) {
        guard !isExpanded else { return }
        isExpanded = true
        panel.setFrame(collapsedFrame(), display: true)
        panel.orderFrontRegardless()
        panel.setFrame(expandedFrame(), display: true, animate: animated)
    }

    // Hover hit-zone for the Dock icon. The zone is exactly the icon's own frame
    // so the panel opens only when the cursor is within the icon's boundaries,
    // not merely near it. Magnification grows the icon upward from its baseline,
    // but the cursor still enters over the resting tile, so the resting frame is
    // the correct target and the zone must not extend above it.
    private func triggerZone(for iconFrame: CGRect) -> CGRect {
        iconFrame
    }

    private func hide(animated: Bool) {
        guard isExpanded else { return }
        isExpanded = false
        panel.setFrame(collapsedFrame(), display: true, animate: animated)
        panel.orderOut(nil)
    }

    private func handleMouseMoved(_ location: NSPoint) {
        // Don't let hover logic hide the panel while the Size slider is driving it.
        if isPreviewingSize { return }

        // Ignore the stray mouseMoved events a Space switch emits; re-showing on
        // one of them is exactly what makes the panel flash on the wrong desktop.
        if let until = spaceChangeSuppressUntil {
            if Date() < until { return }
            spaceChangeSuppressUntil = nil
        }

        let inTriggerZone: Bool
        if let iconFrame = dockIconFrame {
            inTriggerZone = triggerZone(for: iconFrame).contains(location)
        } else {
            // No Dock icon frame yet (permission not granted, or the Dock
            // hasn't registered it). Fall back to a right-edge hover zone so
            // the app still works, just not anchored to the icon.
            let screen = targetScreen().frame
            inTriggerZone = (screen.maxX - location.x) <= edgeTriggerWidth
                && location.y >= screen.minY
                && location.y <= screen.minY + edgeTriggerHeight
        }

        let inPanel = isExpanded && panel.frame.insetBy(dx: -8, dy: -8).contains(location)

        if inTriggerZone || inPanel {
            show(animated: true)
        } else if isExpanded {
            hide(animated: true)
        }
    }

    // Persists a drag-reorder from the panel. Updates the cached order and
    // saves it, but deliberately does not rebuild the panel — the DockView
    // already shows the new order, so rebuilding would only cause a flash.
    private func persistReorder(_ newOrder: [DockApp]) {
        apps = newOrder
        DockStore.shared.save(newOrder)
    }

    private func launch(_ app: DockApp) {
        guard let url = app.resolvedURL() else { return }
        NSWorkspace.shared.open(url)
    }
}
