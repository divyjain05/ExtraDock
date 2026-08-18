import AppKit

/// Passive global mouse-position feed. Read-only monitors like this one don't
/// require the Accessibility permission prompt that event-tapping would.
final class EdgeHoverMonitor {
    private var monitor: Any?

    var onMouseMoved: ((NSPoint) -> Void)?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.onMouseMoved?(NSEvent.mouseLocation)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        stop()
    }
}
