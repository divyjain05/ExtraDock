import AppKit

/// Passive global mouse-position feed. Read-only monitors like this one don't
/// require the Accessibility permission prompt that event-tapping would.
final class EdgeHoverMonitor {
    private var monitor: Any?

    // Keeps the process out of App Nap while the monitor is live. ExtraDock sits
    // idle in the background and never becomes frontmost, so without this the
    // system eventually naps it — throttling the run loop and suspending global
    // mouseMoved delivery, at which point hovering the Dock stops opening the
    // panel until sustained activity wakes the app. .userInitiatedAllowingIdle-
    // SystemSleep prevents App Nap but still lets the Mac sleep normally.
    private var activity: NSObjectProtocol?

    var onMouseMoved: ((NSPoint) -> Void)?

    func start() {
        guard monitor == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Global hover monitoring for the Extra Dock"
        )
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.onMouseMoved?(NSEvent.mouseLocation)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }

    deinit {
        stop()
    }
}
