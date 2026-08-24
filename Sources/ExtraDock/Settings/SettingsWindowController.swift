import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class SettingsViewModel: ObservableObject {
    @Published var apps: [DockApp]
    @Published var launchAtLogin: Bool {
        didSet { LoginItemManager.setEnabled(launchAtLogin) }
    }
    @Published var showMenuBarIcon: Bool {
        didSet {
            AppPreferences.showMenuBarIcon = showMenuBarIcon
            onMenuBarIconChange?(showMenuBarIcon)
        }
    }
    @Published var iconSize: Double {
        didSet {
            AppPreferences.iconSize = CGFloat(iconSize)
            onIconSizeChange?(CGFloat(iconSize))
        }
    }

    var onChange: (() -> Void)?
    var onMenuBarIconChange: ((Bool) -> Void)?
    var onIconSizeChange: ((CGFloat) -> Void)?

    init() {
        apps = DockStore.shared.load()
        launchAtLogin = LoginItemManager.isEnabled
        showMenuBarIcon = AppPreferences.showMenuBarIcon
        iconSize = Double(AppPreferences.iconSize)
    }

    func remove(_ app: DockApp) {
        DockStore.shared.removeApp(id: app.id)
        apps = DockStore.shared.load()
        onChange?()
    }

    func presentAddAppPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Add to ExtraDock"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard DockStore.shared.addApp(at: url) != nil else { return }
        apps = DockStore.shared.load()
        onChange?()
    }
}

final class SettingsWindowController: NSWindowController {
    private let model: SettingsViewModel

    init(
        onChange: @escaping () -> Void,
        onMenuBarIconChange: @escaping (Bool) -> Void,
        onIconSizeChange: @escaping (CGFloat) -> Void
    ) {
        let model = SettingsViewModel()
        model.onChange = onChange
        model.onMenuBarIconChange = onMenuBarIconChange
        model.onIconSizeChange = onIconSizeChange
        self.model = model

        let hosting = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "ExtraDock Settings"
        window.styleMask = [.titled, .closable]

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
