import ApplicationServices
import AppKit

/// Finds the on-screen frame of this app's own icon inside the real Dock, by
/// walking the Dock process's accessibility tree. There's no public API for
/// "where is my Dock icon" — this is the standard workaround, and it's why
/// Accessibility permission is required.
enum DockIconLocator {
    // This tree walk is synchronous and runs on the main thread (a 2s icon-
    // refresh timer, plus the 30s heartbeat that re-arms the hover monitor). A
    // Dock that's slow to answer — common right after waking from a long idle,
    // when it's been paged out — can block a cross-process AX request far past
    // the generous default timeout: long enough to look like the app froze, and
    // to stall the very heartbeat meant to recover it. Cap how long any AX
    // message may block this process. Applied once, process-wide via the
    // system-wide element (a per-element timeout wouldn't cover child elements).
    // ponytail: process-global 2s cap; move the walk off the main thread if it bites.
    private static let capMessagingTimeoutOnce: Void = {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 2)
    }()

    static func currentIconFrame(displayName: String) -> CGRect? {
        guard AccessibilityPermission.isGranted else { return nil }
        _ = capMessagingTimeoutOnce
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return nil
        }

        let axDock = AXUIElementCreateApplication(dockApp.processIdentifier)

        guard let dockList = children(of: axDock).first(where: { role(of: $0) == kAXListRole as String }) else {
            return nil
        }

        for item in children(of: dockList) {
            guard title(of: item) == displayName else { continue }
            return frame(of: item)
        }
        return nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func title(of element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }

        // AX positions are top-left-origin across the whole display arrangement;
        // AppKit screen frames are bottom-left-origin. Flip against the primary
        // screen's height (the one accessibility coordinates are anchored to) —
        // that's the screen at global origin (0,0), not necessarily screens[0].
        let primaryScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        guard let primaryHeight = primaryScreen?.frame.height else { return nil }
        let flippedY = primaryHeight - point.y - size.height
        return CGRect(x: point.x, y: flippedY, width: size.width, height: size.height)
    }
}
