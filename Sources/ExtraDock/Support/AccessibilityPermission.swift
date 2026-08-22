import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system "grant Accessibility access" prompt if not already granted.
    /// Locating our own Dock icon's on-screen position requires inspecting the
    /// Dock process's accessibility tree, which needs this permission.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
