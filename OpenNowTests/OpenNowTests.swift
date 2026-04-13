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

    @Test func preferencesStorePersistsRecentFiles() {
        let defaults = UserDefaults(suiteName: "OpenNowTests-\(UUID().uuidString)")!
        let store = PreferencesStore(defaults: defaults)
        let entry = RecentFileEntry(
            path: "/tmp/example.md",
            displayName: "example.md",
            fileBookmarkData: Data([0x01]),
            directoryBookmarkData: Data([0x02]),
            lastOpenedAt: .distantPast
        )

        store.saveRecentFile(entry)

        let loaded = store.loadRecentFiles()
        #expect(loaded.count == 1)
        #expect(loaded.first?.path == entry.path)
        #expect(loaded.first?.displayName == entry.displayName)
    }
}
