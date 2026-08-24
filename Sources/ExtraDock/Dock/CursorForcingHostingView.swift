import AppKit
import SwiftUI

/// An NSHostingView that always shows a plain arrow cursor. The SwiftUI hosting
/// view sits on top of the panel's other views and covers their bounds, so it —
/// not the views beneath it — is what receives cursor events. Without this, the
/// borderless panel can surface the double-headed resize cursor near its edges.
final class CursorForcingHostingView<Content: View>: NSHostingView<Content> {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate, .inVisibleRect],
            owner: self
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}
