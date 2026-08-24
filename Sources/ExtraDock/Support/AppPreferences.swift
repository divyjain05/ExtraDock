import CoreGraphics
import Foundation

enum AppPreferences {
    private static let showMenuBarIconKey = "showMenuBarIcon"
    private static let iconSizeKey = "iconSize"

    // Icon-size bounds for the extra dock, mirroring the macOS Dock's own
    // small-to-large range. The default matches the size the panel used before
    // this preference existed, so existing users see no change.
    static let defaultIconSize: CGFloat = 56
    static let minIconSize: CGFloat = 40
    static let maxIconSize: CGFloat = 96

    static var showMenuBarIcon: Bool {
        get {
            guard UserDefaults.standard.object(forKey: showMenuBarIconKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: showMenuBarIconKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: showMenuBarIconKey) }
    }

    static var iconSize: CGFloat {
        get {
            guard UserDefaults.standard.object(forKey: iconSizeKey) != nil else { return defaultIconSize }
            let stored = CGFloat(UserDefaults.standard.double(forKey: iconSizeKey))
            return min(max(stored, minIconSize), maxIconSize)
        }
        set { UserDefaults.standard.set(Double(min(max(newValue, minIconSize), maxIconSize)), forKey: iconSizeKey) }
    }
}
