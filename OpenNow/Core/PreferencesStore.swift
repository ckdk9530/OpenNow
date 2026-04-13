import AppKit
import Foundation

final class PreferencesStore {
    private enum EnvironmentKey {
        static let defaultsSuite = "OPENNOW_DEFAULTS_SUITE"
    }

    private enum Key {
        static let recentFiles = "recentFiles"
        static let lastOpen = "lastOpen"
        static let windowFrame = "windowFrame"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let recentFilesLimit = 10

    convenience init(defaults: UserDefaults) {
        self.init(defaults: Optional(defaults))
    }

    init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.defaults = defaults
            return
        }

        if let suiteName = ProcessInfo.processInfo.environment[EnvironmentKey.defaultsSuite],
           let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = suiteDefaults
            return
        }

        self.defaults = .standard
    }

    func loadRecentFiles() -> [RecentFileEntry] {
        guard let data = defaults.data(forKey: Key.recentFiles) else {
            return []
        }

        return (try? decoder.decode([RecentFileEntry].self, from: data)) ?? []
    }

    func saveRecentFile(_ entry: RecentFileEntry) {
        var entries = loadRecentFiles()
        entries.removeAll { $0.path == entry.path }
        entries.insert(entry, at: 0)
        persist(Array(entries.prefix(recentFilesLimit)), forKey: Key.recentFiles)
    }

    func clearRecentFiles() {
        defaults.removeObject(forKey: Key.recentFiles)
    }

    func loadLastOpen() -> LastOpenRecord? {
        guard let data = defaults.data(forKey: Key.lastOpen) else {
            return nil
        }

        return try? decoder.decode(LastOpenRecord.self, from: data)
    }

    func saveLastOpen(_ record: LastOpenRecord?) {
        guard let record else {
            defaults.removeObject(forKey: Key.lastOpen)
            return
        }

        persist(record, forKey: Key.lastOpen)
    }

    func loadWindowFrame() -> CGRect? {
        guard let string = defaults.string(forKey: Key.windowFrame) else {
            return nil
        }

        return NSRectFromString(string)
    }

    func saveWindowFrame(_ frame: CGRect) {
        defaults.set(NSStringFromRect(frame), forKey: Key.windowFrame)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
