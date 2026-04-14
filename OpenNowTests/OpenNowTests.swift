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

        #expect(
            rendered.html.contains(
                #"src="opennow-file:///tmp/project/fixtures/diagram.svg""#
            )
        )
        #expect(rendered.relativeLocalAssetURLs == [URL(fileURLWithPath: "/tmp/project/fixtures/diagram.svg")])
    }

    @Test func rendererRewritesEncodedMarkdownImageSources() throws {
        let renderer = MarkdownRenderer()
        let rendered = try renderer.render(
            markdown: "![Preview](./fixtures/My%20Diagram.svg#preview)",
            baseURL: URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        )

        #expect(
            rendered.html.contains(
                #"src="opennow-file:///tmp/project/fixtures/My%20Diagram.svg""#
            )
        )
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
        #expect(
            rendered.html.contains(
                #"src="opennow-file:///tmp/project/fixtures/diagram.svg""#
            )
        )
    }

    @Test func preferencesStorePersistsRecentFiles() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = RecentFileEntry(
            path: "/tmp/example.md",
            displayName: "example.md",
            fileBookmarkData: Data([0x01]),
            directoryBookmarkData: Data([0x02]),
            accessRootPath: "/tmp",
            lastOpenedAt: .distantPast
        )

        store.saveRecentFile(entry)

        let loaded = store.loadRecentFiles()
        #expect(loaded.count == 1)
        #expect(loaded.first?.path == entry.path)
        #expect(loaded.first?.displayName == entry.displayName)
        #expect(loaded.first?.accessRootPath == entry.accessRootPath)
    }

    @Test func preferencesStorePersistsAuthorizedFolders() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = AuthorizedFolderEntry(
            path: "/Users/dahengchen/Desktop",
            displayName: "Desktop",
            bookmarkData: Data([0xAA]),
            lastUsedAt: .distantPast
        )

        store.saveAuthorizedFolder(entry)

        let loaded = store.loadAuthorizedFolders()
        #expect(loaded == [entry])
    }

    @Test func preferencesStoreRemovesAuthorizedFolders() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let desktop = AuthorizedFolderEntry(
            path: "/Users/dahengchen/Desktop",
            displayName: "Desktop",
            bookmarkData: Data([0xAA]),
            lastUsedAt: .distantPast
        )
        let documents = AuthorizedFolderEntry(
            path: "/Users/dahengchen/Documents",
            displayName: "Documents",
            bookmarkData: Data([0xBB]),
            lastUsedAt: .distantPast
        )

        store.saveAuthorizedFolder(desktop)
        store.saveAuthorizedFolder(documents)
        store.removeAuthorizedFolder(path: desktop.path)

        let loaded = store.loadAuthorizedFolders()
        #expect(loaded == [documents])
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

    @Test func inferredAuthorizationRootUsesTopLevelHomeFolder() {
        let controller = DocumentAccessController()
        let rootURL = controller.inferredAuthorizationRoot(
            for: URL(fileURLWithPath: "/Users/example/Desktop/Notes/Project/readme.md")
        )

        #expect(rootURL.path == "/Users/example/Desktop")
    }

    @Test func inferredAuthorizationRootUsesTopLevelWorkspaceFolder() {
        let controller = DocumentAccessController()
        let rootURL = controller.inferredAuthorizationRoot(
            for: URL(fileURLWithPath: "/Users/example/Project/OpenNow/docs/render-fixtures/complex-render-fixture.md")
        )

        #expect(rootURL.path == "/Users/example/Project")
    }

    @Test func inferredAuthorizationRootUsesMountedVolumeRoot() {
        let controller = DocumentAccessController()
        let rootURL = controller.inferredAuthorizationRoot(
            for: URL(fileURLWithPath: "/Volumes/Archive/Notes/Book/chapter.md")
        )

        #expect(rootURL.path == "/Volumes/Archive")
    }

    @Test func resolveRecentFileFallsBackToCurrentAuthorizedFolder() {
        let controller = DocumentAccessController()
        let entry = RecentFileEntry(
            path: "/Users/example/Project/OpenNow/README.md",
            displayName: "README.md",
            fileBookmarkData: nil,
            directoryBookmarkData: nil,
            accessRootPath: nil,
            lastOpenedAt: .distantPast
        )
        let authorizedFolder = AuthorizedFolderEntry(
            path: "/Users/example/Project",
            displayName: "Project",
            bookmarkData: nil,
            lastUsedAt: .distantPast
        )

        let descriptor = controller.resolveRecentFile(entry, authorizedFolders: [authorizedFolder])

        #expect(descriptor.fileURL.path == entry.path)
        #expect(descriptor.accessRootURL?.path == authorizedFolder.path)
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
