import AppKit

/// Passive mouse-position feed. Read-only monitors like these don't require the
/// Accessibility permission prompt that event-tapping would.
///
/// Two monitors are needed because a global monitor only sees events bound for
/// *other* apps: it goes silent whenever ExtraDock itself is frontmost (its
/// Settings window focused, or the panel taking focus). A local monitor covers
/// exactly that case — events delivered to this app — so hover keeps working no
/// matter which app is in focus.
final class EdgeHoverMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Keeps the process out of App Nap while the monitor is live. ExtraDock sits
    // idle in the background and never becomes frontmost, so without this the
    // system eventually naps it — throttling the run loop and suspending global
    // mouseMoved delivery, at which point hovering the Dock stops opening the
    // panel until sustained activity wakes the app. .userInitiatedAllowingIdle-
    // SystemSleep prevents App Nap but still lets the Mac sleep normally.
    private var activity: NSObjectProtocol?

    var onMouseMoved: ((NSPoint) -> Void)?

    func start() {
        guard globalMonitor == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Global hover monitoring for the Extra Dock"
        )
        // Fires while another app is frontmost.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.onMouseMoved?(NSEvent.mouseLocation)
        }
        // Fires while ExtraDock itself is frontmost. Must return the event so
        // normal delivery is unaffected — this only observes.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.onMouseMoved?(NSEvent.mouseLocation)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }

    deinit {
        stop()
    }
}
