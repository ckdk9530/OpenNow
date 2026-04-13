import AppKit
import Foundation

enum RuntimeEnvironment {
    nonisolated private static var xctestConfigurationKey: String { "XCTestConfigurationFilePath" }
    nonisolated private static var defaultsSuiteKey: String { "OPENNOW_DEFAULTS_SUITE" }
    nonisolated private static var testFileKey: String { "OPENNOW_TEST_FILE" }
    nonisolated private static var xcInjectBundleKey: String { "XCInjectBundle" }
    nonisolated private static var xcInjectBundleIntoKey: String { "XCInjectBundleInto" }
    nonisolated private static var dyldInsertLibrariesKey: String { "DYLD_INSERT_LIBRARIES" }
    nonisolated private static var osActivityModeKey: String { "OS_ACTIVITY_DT_MODE" }

    struct LaunchDiagnostics: Equatable {
        let timestamp: String
        let processIdentifier: Int32
        let isRunningUnderXCTest: Bool
        let defaultsSuite: String?
        let testFilePath: String?
        let relevantEnvironment: [String: String]
    }

    nonisolated private static let relevantEnvironmentKeys = [
        xctestConfigurationKey,
        defaultsSuiteKey,
        testFileKey,
        xcInjectBundleKey,
        xcInjectBundleIntoKey,
        dyldInsertLibrariesKey,
        osActivityModeKey
    ]

    nonisolated static var launchDiagnosticsURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("OpenNow-launch-diagnostics.json")
    }

    nonisolated static func isRunningUnderXCTest(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let value = environment[xctestConfigurationKey] else {
            return false
        }

        return value.isEmpty == false
    }

    nonisolated static func defaultsSuiteName(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard isRunningUnderXCTest(environment) else {
            return nil
        }

        guard let suiteName = environment[defaultsSuiteKey], suiteName.isEmpty == false else {
            return nil
        }

        return suiteName
    }

    nonisolated static func launchTestFileURL(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        guard isRunningUnderXCTest(environment) else {
            return nil
        }

        guard let path = environment[testFileKey], path.isEmpty == false else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    nonisolated static func makeLaunchDiagnostics(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        date: Date = Date(),
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> LaunchDiagnostics {
        let relevantEnvironment = relevantEnvironmentKeys.reduce(into: [String: String]()) { partialResult, key in
            guard let value = environment[key], value.isEmpty == false else {
                return
            }

            partialResult[key] = value
        }

        return LaunchDiagnostics(
            timestamp: ISO8601DateFormatter().string(from: date),
            processIdentifier: processIdentifier,
            isRunningUnderXCTest: isRunningUnderXCTest(environment),
            defaultsSuite: defaultsSuiteName(environment),
            testFilePath: launchTestFileURL(environment)?.path,
            relevantEnvironment: relevantEnvironment
        )
    }

    nonisolated static func writeLaunchDiagnostics(
        _ environment: [String: String] = ProcessInfo.processInfo.environment,
        date: Date = Date(),
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) {
#if DEBUG
        let diagnostics = makeLaunchDiagnostics(
            environment,
            date: date,
            processIdentifier: processIdentifier
        )

        var payload: [String: Any] = [
            "timestamp": diagnostics.timestamp,
            "processIdentifier": diagnostics.processIdentifier,
            "isRunningUnderXCTest": diagnostics.isRunningUnderXCTest,
            "relevantEnvironment": diagnostics.relevantEnvironment
        ]

        payload["defaultsSuite"] = diagnostics.defaultsSuite
        payload["testFilePath"] = diagnostics.testFilePath

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        try? data.write(to: launchDiagnosticsURL, options: .atomic)
#endif
    }
}

final class PreferencesStore {
    private enum Key {
        static let recentFiles = "recentFiles"
        static let lastOpen = "lastOpen"
        static let authorizedFolders = "authorizedFolders"
        static let windowFrame = "windowFrame"
        static let sceneWindowFrame = "NSWindow Frame main"
        static let readerFontScale = "readerFontScale"
        static let splitViewFramePrefix = "NSSplitView Subview Frames "
        static let splitViewFrameSuffix = "SidebarNavigationSplitView"
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

        if let suiteName = RuntimeEnvironment.defaultsSuiteName(),
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

    func loadAuthorizedFolders() -> [AuthorizedFolderEntry] {
        guard let data = defaults.data(forKey: Key.authorizedFolders) else {
            return []
        }

        return (try? decoder.decode([AuthorizedFolderEntry].self, from: data)) ?? []
    }

    func saveAuthorizedFolder(_ entry: AuthorizedFolderEntry) {
        var entries = loadAuthorizedFolders()
        entries.removeAll { $0.path == entry.path }
        entries.insert(entry, at: 0)
        persist(Array(entries.prefix(recentFilesLimit)), forKey: Key.authorizedFolders)
    }

    func removeAuthorizedFolder(path: String) {
        let entries = loadAuthorizedFolders().filter { $0.path != path }
        persist(entries, forKey: Key.authorizedFolders)
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

    func clearWindowFrame() {
        defaults.removeObject(forKey: Key.windowFrame)
    }

    func clearSystemWindowAutosaveArtifacts() {
        defaults.removeObject(forKey: Key.sceneWindowFrame)

        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(Key.splitViewFramePrefix) && key.contains(Key.splitViewFrameSuffix) {
            defaults.removeObject(forKey: key)
        }
    }

    func loadReaderFontScale() -> Double {
        let storedValue = defaults.double(forKey: Key.readerFontScale)
        return storedValue == 0 ? 1.0 : storedValue
    }

    func saveReaderFontScale(_ scale: Double) {
        defaults.set(scale, forKey: Key.readerFontScale)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
