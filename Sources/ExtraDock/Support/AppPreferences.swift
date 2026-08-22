import Foundation

enum AppPreferences {
    private static let showMenuBarIconKey = "showMenuBarIcon"

    static var showMenuBarIcon: Bool {
        get {
            guard UserDefaults.standard.object(forKey: showMenuBarIconKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: showMenuBarIconKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: showMenuBarIconKey) }
    }
}
