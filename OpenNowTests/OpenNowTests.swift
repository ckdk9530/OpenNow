import AppKit
import Foundation
import Testing
@testable import OpenNow

struct OpenNowTests {
    @Test func slugifyCollapsesPunctuationAndWhitespace() {
        #expect(OutlineExtractor.slugify(" Hello, World! ") == "hello-world")
    }

    @Test func outlineExtractorBuildsUniqueAnchors() {
        let markdown = """
        # Hello World
        ## Hello World
        # Hello World
        """

        let items = OutlineExtractor.extract(from: markdown)

        #expect(items.count == 3)
        #expect(items[0].anchor == "hello-world")
        #expect(items[1].anchor == "hello-world-1")
        #expect(items[2].anchor == "hello-world-2")
    }

    @Test func rendererProducesAnchoredHTML() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(markdown: "# Title\n\nText", baseURL: URL(fileURLWithPath: "/tmp"))

        #expect(rendered.html.contains(#"id="title""#))
        #expect(rendered.outlineItems.map(\.title) == ["Title"])
    }

    @Test func rendererConvertsPipeTablesIntoHTMLTables() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: """
            | Name | Count | Status |
            | :-- | --: | :--: |
            | Alpha | 42 | **Ready** |
            | Beta | 7 | `Queued` |
            """,
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(rendered.html.contains("<table>"))
        #expect(rendered.html.contains(#"<th align="left">Name</th>"#))
        #expect(rendered.html.contains(#"<th align="right">Count</th>"#))
        #expect(rendered.html.contains(#"<th align="center">Status</th>"#))
        #expect(rendered.html.contains("<strong>Ready</strong>"))
        #expect(rendered.html.contains("<code>Queued</code>"))
    }

    @Test func rendererRewritesLocalImageSourcesToCustomScheme() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: "![Diagram](./fixtures/diagram.svg)",
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(rendered.html.contains(#"src="opennow-file:///tmp/project/fixtures/diagram.svg""#))
        #expect(rendered.relativeLocalAssetURLs == [URL(fileURLWithPath: "/tmp/project/fixtures/diagram.svg")])
    }

    @Test func rendererRewritesEncodedMarkdownImageSources() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: "![Preview](./fixtures/My%20Diagram.svg#preview)",
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(rendered.html.contains(#"src="opennow-file:///tmp/project/fixtures/My%20Diagram.svg""#))
    }

    @Test func rendererCollectsBracketedRelativeImagePathsWithSpaces() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: "![Preview](<./fixtures/My Diagram.png>)",
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(rendered.html.contains(#"src="opennow-file:///tmp/project/fixtures/My%20Diagram.png""#))
        #expect(rendered.relativeLocalAssetURLs == [URL(fileURLWithPath: "/tmp/project/fixtures/My Diagram.png")])
    }

    @Test func rendererRewritesImagesInsideGeneratedTables() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: """
            | Preview | Notes |
            | --- | --- |
            | ![Diagram](./fixtures/diagram.svg) | local image inside table |
            """,
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(rendered.html.contains("<table>"))
        #expect(rendered.html.contains(#"src="opennow-file:///tmp/project/fixtures/diagram.svg""#))
    }

    @Test func readerAssetURLSchemeRoundTripsFilePaths() {
        let fileURL = URL(fileURLWithPath: "/tmp/project/fixtures/diagram.svg")
        let rewrittenURL = ReaderAssetURLScheme.makeURL(for: fileURL)

        #expect(rewrittenURL.absoluteString == "opennow-file:///tmp/project/fixtures/diagram.svg")
        #expect(ReaderAssetURLScheme.resolve(rewrittenURL) == fileURL)
    }

    @Test func readerAssetURLSchemeRoundTripsEncodedAndLegacyPaths() {
        let fileURL = URL(fileURLWithPath: "/tmp/project/fixtures/My Diagram #1.svg")
        let rewrittenURL = ReaderAssetURLScheme.makeURL(for: fileURL)
        let legacyURL = URL(string: "opennow-file://local/tmp/project/fixtures/My%20Diagram%20%231.svg")!

        #expect(rewrittenURL.absoluteString == "opennow-file:///tmp/project/fixtures/My%20Diagram%20%231.svg")
        #expect(ReaderAssetURLScheme.resolve(rewrittenURL) == fileURL)
        #expect(ReaderAssetURLScheme.resolve(legacyURL) == fileURL)
    }

    @Test func readerAssetSecurityScopeStoreRequestsAuthorizationOnDemand() {
        let store = ReaderAssetSecurityScopeStore.shared
        let fileURL = URL(fileURLWithPath: "/tmp/project/assets/diagram.png")
        let supportFolderURL = URL(fileURLWithPath: "/tmp/project/assets", isDirectory: true)
        var requestedURL: URL?

        store.clear()
        store.setAuthorizationHandler { url in
            requestedURL = url
            return supportFolderURL
        }
        defer {
            store.setAuthorizationHandler(nil)
            store.clear()
        }

        let scopeURL = store.requestAuthorization(for: fileURL)

        #expect(requestedURL == fileURL)
        #expect(scopeURL == supportFolderURL)
    }

    @Test func preferencesStorePersistsRecentFiles() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = RecentFileEntry(
            path: "/tmp/example.md",
            displayName: "example.md",
            fileBookmarkData: Data([0x01]),
            lastOpenedAt: .distantPast
        )

        store.saveRecentFile(entry)

        let loaded = store.loadRecentFiles()
        #expect(loaded.count == 1)
        #expect(loaded.first?.path == entry.path)
        #expect(loaded.first?.displayName == entry.displayName)
        #expect(loaded.first?.fileBookmarkData == entry.fileBookmarkData)
    }

    @Test func preferencesStorePersistsDocumentSupportAccess() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = DocumentSupportAccessEntry(
            documentPath: "/tmp/example.md",
            documentBookmarkData: Data([0x01]),
            supportFolderPath: "/tmp/assets",
            supportFolderBookmarkData: Data([0x02]),
            lastResolvedAt: .distantPast
        )

        store.saveDocumentSupportAccess(entry)

        let loaded = store.loadDocumentSupportAccess()
        #expect(loaded == [entry])
    }

    @Test func preferencesStoreClearsLegacyAuthorizedFolders() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = AuthorizedFolderEntry(
            path: "/Users/dahengchen/Desktop",
            displayName: "Desktop",
            bookmarkData: Data([0xAA]),
            lastUsedAt: .distantPast
        )

        store.saveAuthorizedFolder(entry)
        store.clearAuthorizedFolders()

        #expect(store.loadAuthorizedFolders().isEmpty)
    }

    @Test func preferencesStoreClearsWindowAndSplitViewAutosaveArtifacts() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let splitViewKey = "NSSplitView Subview Frames main, SidebarNavigationSplitView"
        let unrelatedSplitViewKey = "NSSplitView Subview Frames main, UnrelatedSplitView"

        defaults.set("750 64 720 859 0 0 1470 923 ", forKey: "NSWindow Frame main")
        defaults.set(
            [
                "0.000000, 0.000000, 248.000000, 2003.500000, NO, NO",
                "0.000000, 0.000000, 1470.000000, 2003.500000, NO, NO"
            ],
            forKey: splitViewKey
        )
        defaults.set("keep", forKey: unrelatedSplitViewKey)

        store.clearSystemWindowAutosaveArtifacts()

        #expect(defaults.object(forKey: "NSWindow Frame main") == nil)
        #expect(defaults.object(forKey: splitViewKey) == nil)
        #expect(defaults.string(forKey: unrelatedSplitViewKey) == "keep")
    }

    @Test func preferencesStoreTracksDefaultViewerOnboardingCompletion() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)

        #expect(store.hasCompletedDefaultViewerOnboarding() == false)

        store.markDefaultViewerOnboardingCompleted()

        #expect(store.hasCompletedDefaultViewerOnboarding())
    }

    @Test func inferredAuthorizationRootUsesTopLevelHomeFolder() {
        let controller = DocumentAccessController()
        let rootURL = controller.inferredAuthorizationRoot(
            for: URL(fileURLWithPath: "/Users/example/Desktop/Notes/Project/readme.md")
        )

        #expect(rootURL.path == "/Users/example/Desktop")
    }

    @Test func preferredSupportFolderUsesCommonAncestorForMissingAssets() {
        let controller = DocumentAccessController()
        let preferred = controller.preferredSupportFolder(
            for: [
                URL(fileURLWithPath: "/Users/example/Project/assets/a.png"),
                URL(fileURLWithPath: "/Users/example/Project/assets/sub/b.png")
            ],
            documentDirectoryURL: URL(fileURLWithPath: "/Users/example/Project/docs", isDirectory: true)
        )

        #expect(preferred.path == "/Users/example/Project/assets")
    }

    @Test func migrateLegacyAuthorizedFoldersCreatesDocumentBoundSupportAccess() {
        let controller = DocumentAccessController()
        let recentFile = RecentFileEntry(
            path: "/Users/example/Project/docs/readme.md",
            displayName: "readme.md",
            fileBookmarkData: nil,
            lastOpenedAt: .distantPast
        )
        let authorizedFolder = AuthorizedFolderEntry(
            path: "/Users/example/Project",
            displayName: "Project",
            bookmarkData: nil,
            lastUsedAt: .distantPast
        )

        let migratedEntries = controller.migrateLegacyAuthorizedFolders(
            [authorizedFolder],
            recentFiles: [recentFile]
        )

        #expect(migratedEntries.count == 1)
        #expect(migratedEntries[0].documentPath == recentFile.path)
        #expect(migratedEntries[0].supportFolderPath == authorizedFolder.path)
    }

    @Test @MainActor func supportingFilesCoordinatorPersistsDocumentScopedRecovery() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let preferencesStore = PreferencesStore(defaults: defaults)
        let alertPresenter = MockDocumentAlertPresenter()
        let coordinator = SupportingFilesAccessCoordinator(
            documentAccessController: DocumentAccessController(),
            preferencesStore: preferencesStore,
            alertPresenter: alertPresenter
        )
        let documentURL = URL(fileURLWithPath: "/tmp/project/docs/readme.md")
        let unresolvedAssetURL = URL(fileURLWithPath: "/tmp/project/assets/diagram.png")
        let document = OpenedDocument(
            url: documentURL,
            directoryURL: documentURL.deletingLastPathComponent(),
            rawMarkdown: "![Diagram](../assets/diagram.png)",
            renderedHTML: "<img>",
            outlineItems: [],
            relativeLocalAssetURLs: [unresolvedAssetURL],
            unresolvedLocalAssetURLs: [],
            supportAccessState: .ready,
            lastKnownModificationDate: nil
        )

        alertPresenter.recoveryChoices = [.selectedFolder(URL(fileURLWithPath: "/tmp/project", isDirectory: true))]
        coordinator.loadPersistedEntries()

        let grantedURL = coordinator.requestSupportAccess(for: document, failingAssetURL: unresolvedAssetURL)

        #expect(grantedURL?.path == "/tmp/project")
        #expect(preferencesStore.loadDocumentSupportAccess().count == 1)
        #expect(preferencesStore.loadDocumentSupportAccess().first?.documentPath == documentURL.path)
    }

    @Test @MainActor func supportingFilesCoordinatorSuppressesPromptForCurrentSession() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let preferencesStore = PreferencesStore(defaults: defaults)
        let alertPresenter = MockDocumentAlertPresenter()
        let coordinator = SupportingFilesAccessCoordinator(
            documentAccessController: DocumentAccessController(),
            preferencesStore: preferencesStore,
            alertPresenter: alertPresenter
        )
        let documentURL = URL(fileURLWithPath: "/tmp/project/docs/readme.md")
        let unresolvedAssetURL = URL(fileURLWithPath: "/tmp/project/assets/diagram.png")
        let document = OpenedDocument(
            url: documentURL,
            directoryURL: documentURL.deletingLastPathComponent(),
            rawMarkdown: "![Diagram](../assets/diagram.png)",
            renderedHTML: "<img>",
            outlineItems: [],
            relativeLocalAssetURLs: [unresolvedAssetURL],
            unresolvedLocalAssetURLs: [],
            supportAccessState: .ready,
            lastKnownModificationDate: nil
        )

        alertPresenter.recoveryChoices = [.continueWithoutImages]
        coordinator.loadPersistedEntries()

        let firstAttempt = coordinator.requestSupportAccess(for: document, failingAssetURL: unresolvedAssetURL)
        let secondAttempt = coordinator.requestSupportAccess(for: document, failingAssetURL: unresolvedAssetURL)

        #expect(firstAttempt == nil)
        #expect(secondAttempt == nil)
        #expect(alertPresenter.recoveryCallCount == 1)
    }

    @Test @MainActor func coordinatorRequestsSupportingFilesAccessWhenRelativeAssetMarkdownOpens() async throws {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let preferencesStore = PreferencesStore(defaults: defaults)
        let documentAccessController = DocumentAccessController()
        let panelPresenter = MockDocumentPanelPresenter()
        let alertPresenter = MockDocumentAlertPresenter()
        let windowChromeController = MockWindowChromeController()
        let coordinator = AppLaunchCoordinator(
            preferencesStore: preferencesStore,
            documentAccessController: documentAccessController,
            markdownRenderer: MarkdownRenderer(),
            fileWatcher: FileWatcher(),
            panelPresenter: panelPresenter,
            alertPresenter: alertPresenter,
            windowChromeController: windowChromeController,
            allowsSupportingFilesAccessRecovery: true
        )
        let markdownURL = try makeMarkdownFixture(
            named: "RelativeAssets.md",
            contents: """
            # Fixture

            ![Diagram](./diagram.png)
            """
        )
        let expectedSupportFolderURL = documentAccessController.inferredAuthorizationRoot(for: markdownURL)
        alertPresenter.recoveryChoices = [.selectedFolder(expectedSupportFolderURL)]

        coordinator.start()
        coordinator.openDocument(at: markdownURL)
        await waitUntil {
            coordinator.activeDocument?.url == markdownURL
        }

        #expect(alertPresenter.recoveryCallCount == 1)
        #expect(coordinator.activeDocument?.supportAccessState == .ready)
        #expect(preferencesStore.loadDocumentSupportAccess().count == 1)
        #expect(preferencesStore.loadDocumentSupportAccess().first?.supportFolderPath == expectedSupportFolderURL.path)
        coordinator.closeCurrentFile()
    }

    @Test @MainActor func coordinatorDefersLegacyAuthorizedFolderMigrationUntilStartupMaintenance() async {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let preferencesStore = PreferencesStore(defaults: defaults)
        let recentFile = RecentFileEntry(
            path: "/Users/example/Project/docs/readme.md",
            displayName: "readme.md",
            fileBookmarkData: nil,
            lastOpenedAt: .distantPast
        )
        let authorizedFolder = AuthorizedFolderEntry(
            path: "/Users/example/Project",
            displayName: "Project",
            bookmarkData: nil,
            lastUsedAt: .distantPast
        )
        let coordinator = AppLaunchCoordinator(
            preferencesStore: preferencesStore,
            documentAccessController: DocumentAccessController(),
            markdownRenderer: MarkdownRenderer(),
            fileWatcher: FileWatcher(),
            panelPresenter: MockDocumentPanelPresenter(),
            alertPresenter: MockDocumentAlertPresenter(),
            windowChromeController: MockWindowChromeController(),
            startupMaintenanceDelay: .milliseconds(10)
        )

        preferencesStore.saveRecentFile(recentFile)
        preferencesStore.saveAuthorizedFolder(authorizedFolder)

        coordinator.start()

        #expect(preferencesStore.loadDocumentSupportAccess().isEmpty)
        #expect(preferencesStore.loadAuthorizedFolders() == [authorizedFolder])

        await waitUntil {
            preferencesStore.loadDocumentSupportAccess().count == 1
        }

        #expect(preferencesStore.loadDocumentSupportAccess().first?.documentPath == recentFile.path)
        #expect(preferencesStore.loadDocumentSupportAccess().first?.supportFolderPath == authorizedFolder.path)
        #expect(preferencesStore.loadAuthorizedFolders().isEmpty)
    }

    @Test @MainActor func coordinatorOffersOpenPanelAfterRecentOpenFailure() async throws {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let preferencesStore = PreferencesStore(defaults: defaults)
        let documentAccessController = DocumentAccessController()
        let panelPresenter = MockDocumentPanelPresenter()
        let alertPresenter = MockDocumentAlertPresenter()
        let windowChromeController = MockWindowChromeController()
        let coordinator = AppLaunchCoordinator(
            preferencesStore: preferencesStore,
            documentAccessController: documentAccessController,
            markdownRenderer: MarkdownRenderer(),
            fileWatcher: FileWatcher(),
            panelPresenter: panelPresenter,
            alertPresenter: alertPresenter,
            windowChromeController: windowChromeController
        )
        let retryDocumentURL = try makeMarkdownFixture(
            named: "Recovered.md",
            contents: """
            # Recovered

            Body
            """
        )
        let missingEntry = RecentFileEntry(
            path: "/tmp/OpenNow-Missing-\(UUID().uuidString).md",
            displayName: "Missing.md",
            fileBookmarkData: nil,
            lastOpenedAt: .distantPast
        )
        panelPresenter.documentURLs = [retryDocumentURL]
        alertPresenter.loadFailureActions = [.openMarkdownPanel]

        coordinator.start()
        coordinator.openRecent(missingEntry)
        await waitUntil {
            panelPresenter.documentPickCallCount == 1
        }
        await waitUntil {
            coordinator.activeDocument?.url == retryDocumentURL
        }

        #expect(alertPresenter.loadFailureCallCount == 1)
        #expect(alertPresenter.lastAllowsOpenMarkdownPanel == true)
        coordinator.closeCurrentFile()
    }

    @Test func runtimeEnvironmentIgnoresOpenNowHooksOutsideXCTest() {
        let environment = [
            "OPENNOW_DEFAULTS_SUITE": "OpenNowManual",
            "OPENNOW_TEST_FILE": "/tmp/fixture.md"
        ]

        #expect(RuntimeEnvironment.isRunningUnderXCTest(environment) == false)
        #expect(RuntimeEnvironment.defaultsSuiteName(environment) == nil)
        #expect(RuntimeEnvironment.launchTestFileURL(environment) == nil)
    }

    @Test func runtimeEnvironmentExposesOpenNowHooksInsideXCTest() {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
            "OPENNOW_DEFAULTS_SUITE": "OpenNowUITests",
            "OPENNOW_TEST_FILE": "/tmp/fixture.md"
        ]

        #expect(RuntimeEnvironment.isRunningUnderXCTest(environment))
        #expect(RuntimeEnvironment.defaultsSuiteName(environment) == "OpenNowUITests")
        #expect(RuntimeEnvironment.launchTestFileURL(environment)?.path == "/tmp/fixture.md")
    }

    @Test func runtimeEnvironmentExposesOpenNowHooksWithExplicitOptIn() {
        let environment = [
            "OPENNOW_ENABLE_TEST_HOOKS": "1",
            "OPENNOW_DEFAULTS_SUITE": "OpenNowUITests",
            "OPENNOW_TEST_MARKDOWN": "# Fixture"
        ]

        #expect(RuntimeEnvironment.isRunningUnderXCTest(environment))
        #expect(RuntimeEnvironment.defaultsSuiteName(environment) == "OpenNowUITests")
        #expect(RuntimeEnvironment.launchTestMarkdown(environment) == "# Fixture")
    }

    @Test func runtimeEnvironmentMaterializesLaunchMarkdownInsideProcessTempDirectory() throws {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
            "OPENNOW_TEST_MARKDOWN": "# Fixture\n\nBody",
            "OPENNOW_TEST_FILENAME": "LaunchFixture.md"
        ]

        let url = try #require(RuntimeEnvironment.launchTestDocumentURL(environment))
        let contents = try String(contentsOf: url, encoding: .utf8)

        #expect(url.lastPathComponent == "LaunchFixture.md")
        #expect(contents == "# Fixture\n\nBody")
    }

    @Test func runtimeEnvironmentDiagnosticsCaptureOnlyRelevantTestSignals() {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
            "OPENNOW_DEFAULTS_SUITE": "OpenNowUITests",
            "OPENNOW_TEST_FILE": "/tmp/fixture.md",
            "XCInjectBundleInto": "/Applications/OpenNow.app/Contents/MacOS/OpenNow",
            "UNRELATED": "ignore-me"
        ]

        let diagnostics = RuntimeEnvironment.makeLaunchDiagnostics(
            environment,
            date: Date(timeIntervalSince1970: 0),
            processIdentifier: 42
        )

        #expect(diagnostics.timestamp == "1970-01-01T00:00:00Z")
        #expect(diagnostics.processIdentifier == 42)
        #expect(diagnostics.isRunningUnderXCTest)
        #expect(diagnostics.defaultsSuite == "OpenNowUITests")
        #expect(diagnostics.testFilePath == "/tmp/fixture.md")
        #expect(diagnostics.relevantEnvironment["XCTestConfigurationFilePath"] == "/tmp/session.xctestconfiguration")
        #expect(diagnostics.relevantEnvironment["XCInjectBundleInto"] == "/Applications/OpenNow.app/Contents/MacOS/OpenNow")
        #expect(diagnostics.relevantEnvironment["UNRELATED"] == nil)
    }
}

@MainActor
private final class MockDocumentPanelPresenter: DocumentPanelPresenting {
    var documentURLs: [URL?] = []
    private(set) var documentPickCallCount = 0

    func pickDocumentURL(startingDirectory: URL?) -> URL? {
        documentPickCallCount += 1
        guard documentURLs.isEmpty == false else {
            return nil
        }

        return documentURLs.removeFirst()
    }
}

@MainActor
private final class MockDocumentAlertPresenter: DocumentAlertPresenting {
    var recoveryChoices: [SupportingFilesRecoveryChoice] = []
    var retrySupportingFilesSelectionResults: [Bool] = []
    var loadFailureActions: [LoadFailureAlertAction] = []
    private(set) var recoveryCallCount = 0
    private(set) var retrySelectionCallCount = 0
    private(set) var loadFailureCallCount = 0
    private(set) var lastAllowsOpenMarkdownPanel = false

    func recoverSupportingFilesAccess(
        for documentURL: URL,
        suggestedDirectory: URL?,
        unresolvedAssetURLs: [URL]
    ) -> SupportingFilesRecoveryChoice {
        recoveryCallCount += 1
        guard recoveryChoices.isEmpty == false else {
            return .unavailable
        }

        return recoveryChoices.removeFirst()
    }

    func retrySupportingFilesSelection(
        selectedDirectory: URL,
        suggestedDirectory: URL,
        unresolvedAssetURLs: [URL]
    ) -> Bool {
        retrySelectionCallCount += 1
        guard retrySupportingFilesSelectionResults.isEmpty == false else {
            return false
        }

        return retrySupportingFilesSelectionResults.removeFirst()
    }

    func presentLoadFailure(
        message: String,
        allowsOpenMarkdownPanel: Bool
    ) -> LoadFailureAlertAction {
        loadFailureCallCount += 1
        lastAllowsOpenMarkdownPanel = allowsOpenMarkdownPanel
        guard loadFailureActions.isEmpty == false else {
            return .dismiss
        }

        return loadFailureActions.removeFirst()
    }
}

@MainActor
private final class MockWindowChromeController: WindowChromeControlling {
    private(set) var appliedDocumentURLs: [URL?] = []

    func attach(window: NSWindow) {}

    func persistFrame(window: NSWindow, frame: CGRect) {}

    func apply(document: OpenedDocument?) {
        appliedDocumentURLs.append(document?.url)
    }
}

private func makeMarkdownFixture(named filename: String, contents: String) throws -> URL {
    let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("OpenNowTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

    let markdownURL = rootURL.appendingPathComponent(filename)
    try contents.write(to: markdownURL, atomically: true, encoding: .utf8)
    return markdownURL
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollIntervalNanoseconds: UInt64 = 50_000_000,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while condition() == false, DispatchTime.now().uptimeNanoseconds < deadline {
        try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    #expect(condition())
}
