import XCTest

final class OpenNowUITests: XCTestCase {
    private enum LaunchEnvironmentKey {
        static let defaultsSuite = "OPENNOW_DEFAULTS_SUITE"
        static let testFile = "OPENNOW_TEST_FILE"
    }

    private struct StoredLastOpenRecord: Codable {
        let path: String
        let displayName: String
        let fileBookmarkData: Data?
        let directoryBookmarkData: Data?
        let accessRootPath: String?
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
        let errorState = app.descendants(matching: .any).matching(identifier: "document-error-state").firstMatch
        let loadingState = app.descendants(matching: .any).matching(identifier: "document-loading-state").firstMatch
        let openButton = app.buttons["Open Markdown…"]

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(detailPane.waitForExistence(timeout: 5))
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))

        let windowFrame = window.frame

        XCTAssertGreaterThan(windowFrame.width, 700)
        XCTAssertGreaterThan(windowFrame.height, 500)
        XCTAssertFalse(documentHeader.exists)
        XCTAssertFalse(errorState.exists)
        XCTAssertFalse(loadingState.exists)
    }

    @MainActor
    func testOpensMarkdownFileFromLaunchEnvironment() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("OpenNowUITest.md")
        try """
        # UI Test Title

        Body
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = temporaryURL.path
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
    func testStaleRestoredDocumentFallsBackToEmptyState() throws {
        let suiteName = "OpenNowUITests-Restore-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let record = StoredLastOpenRecord(
            path: "/tmp/OpenNow-Missing-\(UUID().uuidString).md",
            displayName: "Missing.md",
            fileBookmarkData: nil,
            directoryBookmarkData: nil,
            accessRootPath: nil
        )
        defaults.set(try JSONEncoder().encode(record), forKey: "lastOpen")

        let app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironmentKey.defaultsSuite] = suiteName
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = ""
        app.launch()

        let openButton = app.buttons["Open Markdown…"]
        let errorState = app.descendants(matching: .any).matching(identifier: "document-error-state").firstMatch

        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        XCTAssertFalse(errorState.waitForExistence(timeout: 2))
    }

    @MainActor
    func testComplexFixtureRendersBodyContent() throws {
        let fixturePath = repositoryRootURL()
            .appendingPathComponent("docs/render-fixtures/complex-render-fixture.md")
            .path
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixturePath))

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = fixturePath
        app.launch()

        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        let outlineItem = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "outline-item-")
        ).firstMatch
        let sidebarEmptyState = app.descendants(matching: .any).matching(identifier: "sidebar-empty-state").firstMatch
        let errorState = app.descendants(matching: .any).matching(identifier: "document-error-state").firstMatch

        XCTAssertTrue(documentHeader.waitForExistence(timeout: 10))
        XCTAssertTrue(outlineItem.waitForExistence(timeout: 10))
        XCTAssertFalse(sidebarEmptyState.exists)
        XCTAssertFalse(errorState.exists)
    }

    @MainActor
    func testDocumentLayoutKeepsSidebarHeaderAndReaderSeparated() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("OpenNowUILayout.md")
        try """
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
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = temporaryURL.path
        app.launch()

        let detailPane = app.descendants(matching: .any).matching(identifier: "reader-detail-pane").firstMatch
        let outlineButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "outline-item-")
        ).firstMatch
        let window = app.windows.firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(detailPane.waitForExistence(timeout: 10))
        XCTAssertTrue(outlineButton.waitForExistence(timeout: 10))

        let windowFrame = window.frame
        let detailFrame = detailPane.frame
        let outlineFrame = outlineButton.frame

        XCTAssertGreaterThan(windowFrame.width, 700)
        XCTAssertGreaterThan(detailFrame.width, windowFrame.width * 0.5)
        XCTAssertGreaterThan(outlineFrame.width, 75)
        XCTAssertLessThan(outlineFrame.height, 32)
        XCTAssertLessThanOrEqual(detailFrame.maxX, windowFrame.maxX)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Document Layout"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironmentKey.defaultsSuite] = "OpenNowUITests-\(UUID().uuidString)"
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = ""
        return app
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
