import Foundation

final class DockStore {
    static let shared = DockStore()

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ExtraDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dock-apps.json")
    }

    func load() -> [DockApp] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([DockApp].self, from: data)) ?? []
    }

    func save(_ apps: [DockApp]) {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    @discardableResult
    func addApp(at url: URL) -> DockApp? {
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        var apps = load()
        let newApp = DockApp(name: name, bookmarkData: bookmark)
        apps.append(newApp)
        save(apps)
        return newApp
    }

    func removeApp(id: UUID) {
        var apps = load()
        apps.removeAll { $0.id == id }
        save(apps)
    }
}
