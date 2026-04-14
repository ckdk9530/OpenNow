import XCTest

final class OpenNowUITests: XCTestCase {
    private enum LaunchEnvironmentKey {
        static let enableTestHooks = "OPENNOW_ENABLE_TEST_HOOKS"
        static let defaultsSuite = "OPENNOW_DEFAULTS_SUITE"
        static let testFile = "OPENNOW_TEST_FILE"
        static let testMarkdown = "OPENNOW_TEST_MARKDOWN"
        static let testFilename = "OPENNOW_TEST_FILENAME"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoEmptyState() throws {
        let app = makeApp()
        app.launch()

        let detailPane = app.descendants(matching: .any).matching(identifier: "reader-detail-pane").firstMatch
        let window = app.windows.firstMatch
        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        let loadingState = app.descendants(matching: .any).matching(identifier: "document-loading-state").firstMatch
        let openButton = app.buttons["Open Markdown…"]

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(detailPane.waitForExistence(timeout: 5))
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))

        let windowFrame = window.frame

        XCTAssertGreaterThan(windowFrame.width, 700)
        XCTAssertGreaterThan(windowFrame.height, 500)
        XCTAssertFalse(documentHeader.exists)
        XCTAssertFalse(loadingState.exists)
    }

    @MainActor
    func testOpensMarkdownFileFromLaunchEnvironment() throws {
        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testMarkdown] = """
        # UI Test Title

        Body
        """
        app.launchEnvironment[LaunchEnvironmentKey.testFilename] = "OpenNowUITest.md"
        app.launch()

        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        XCTAssertTrue(documentHeader.waitForExistence(timeout: 10))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }

    @MainActor
    func testStoredRecentFilesDoNotAutoOpenAtLaunch() throws {
        let suiteName = "OpenNowUITests-Restore-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(
            try JSONSerialization.data(
                withJSONObject: [[
                    "path": "/tmp/OpenNow-Missing-\(UUID().uuidString).md",
                    "displayName": "Missing.md",
                    "fileBookmarkData": NSNull(),
                    "directoryBookmarkData": NSNull(),
                    "accessRootPath": NSNull(),
                    "lastOpenedAt": 0
                ]]
            ),
            forKey: "recentFiles"
        )

        let app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironmentKey.defaultsSuite] = suiteName
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = ""
        app.launch()

        let openButton = app.buttons["Open Markdown…"]
        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch

        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        XCTAssertFalse(documentHeader.exists)
    }

    @MainActor
    func testComplexFixtureRendersBodyContent() throws {
        let fixtureURL = repositoryRootURL()
            .appendingPathComponent("docs/render-fixtures/complex-render-fixture.md")
        let fixtureMarkdown = try String(contentsOf: fixtureURL, encoding: .utf8)

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testMarkdown] = fixtureMarkdown
        app.launchEnvironment[LaunchEnvironmentKey.testFilename] = "complex-render-fixture.md"
        app.launch()

        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        let outlineItem = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "outline-item-")
        ).firstMatch
        let sidebarEmptyState = app.descendants(matching: .any).matching(identifier: "sidebar-empty-state").firstMatch

        XCTAssertTrue(documentHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(outlineItem.waitForExistence(timeout: 10))
        XCTAssertFalse(sidebarEmptyState.exists)
    }

    @MainActor
    func testDocumentLayoutKeepsSidebarHeaderAndReaderSeparated() throws {
        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testMarkdown] = """
        # Layout Title

        ## Overview

        This paragraph exists to force a visible reading area.

        ## Table

        | Name | Value | Notes |
        | --- | --- | --- |
        | alpha | 1 | row |
        | beta | 2 | row |

        ## Code

        ```swift
        let message = "OpenNow layout smoke test"
        print(message)
        ```
        """
        app.launchEnvironment[LaunchEnvironmentKey.testFilename] = "OpenNowUILayout.md"
        app.launch()

        let detailPane = app.descendants(matching: .any).matching(identifier: "reader-detail-pane").firstMatch
        let sidebarPane = app.descendants(matching: .any).matching(identifier: "sidebar-pane").firstMatch
        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        let outlineButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "outline-item-")
        ).firstMatch
        let window = app.windows.firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(detailPane.waitForExistence(timeout: 10))
        XCTAssertTrue(sidebarPane.waitForExistence(timeout: 10))
        XCTAssertTrue(documentHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(outlineButton.waitForExistence(timeout: 10))

        let windowFrame = window.frame
        let sidebarFrame = sidebarPane.frame
        let detailFrame = detailPane.frame
        let outlineFrame = outlineButton.frame
        XCTAssertGreaterThan(windowFrame.width, 700)
        XCTAssertGreaterThan(sidebarFrame.width, 180)
        XCTAssertGreaterThan(detailFrame.width, windowFrame.width * 0.5)
        XCTAssertGreaterThan(outlineFrame.width, 75)
        XCTAssertGreaterThan(detailFrame.width, sidebarFrame.width * 1.8)
        XCTAssertLessThanOrEqual(outlineFrame.maxX, sidebarFrame.maxX + 2)
        XCTAssertLessThanOrEqual(detailFrame.maxX, windowFrame.maxX)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Document Layout"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironmentKey.enableTestHooks] = "1"
        app.launchEnvironment[LaunchEnvironmentKey.defaultsSuite] = "OpenNowUITests-\(UUID().uuidString)"
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = ""
        app.launchEnvironment[LaunchEnvironmentKey.testMarkdown] = ""
        app.launchEnvironment[LaunchEnvironmentKey.testFilename] = ""
        return app
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
