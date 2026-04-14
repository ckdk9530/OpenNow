import Foundation

enum ReaderPageDirection {
    case up
    case down
}

struct OutlineItem: Identifiable, Codable, Equatable {
    let title: String
    let level: Int
    let anchor: String

    var id: String { anchor }
}

struct RenderedDocument {
    let html: String
    let outlineItems: [OutlineItem]
    let containsRelativeImages: Bool
    let relativeLocalAssetURLs: [URL]
}

enum SupportAccessState: String, Codable, Equatable {
    case ready
    case recovering
    case suppressed
    case unavailable
}

struct OpenedDocument {
    let url: URL
    let directoryURL: URL
    let rawMarkdown: String
    let renderedHTML: String
    let outlineItems: [OutlineItem]
    let relativeLocalAssetURLs: [URL]
    let unresolvedLocalAssetURLs: [URL]
    let supportAccessState: SupportAccessState
    let lastKnownModificationDate: Date?

    func updatingSupportAccess(
        state: SupportAccessState,
        unresolvedLocalAssetURLs: [URL]
    ) -> OpenedDocument {
        OpenedDocument(
            url: url,
            directoryURL: directoryURL,
            rawMarkdown: rawMarkdown,
            renderedHTML: renderedHTML,
            outlineItems: outlineItems,
            relativeLocalAssetURLs: relativeLocalAssetURLs,
            unresolvedLocalAssetURLs: unresolvedLocalAssetURLs,
            supportAccessState: state,
            lastKnownModificationDate: lastKnownModificationDate
        )
    }
}

struct AuthorizedFolderEntry: Identifiable, Codable, Equatable {
    let path: String
    let displayName: String
    let bookmarkData: Data?
    let lastUsedAt: Date

    var id: String { path }
}

struct DocumentSupportAccessEntry: Identifiable, Codable, Equatable {
    let documentPath: String
    let documentBookmarkData: Data?
    let supportFolderPath: String
    let supportFolderBookmarkData: Data?
    let lastResolvedAt: Date

    var id: String { documentPath }
}

struct RecentFileEntry: Identifiable, Codable, Equatable {
    let path: String
    let displayName: String
    let fileBookmarkData: Data?
    let lastOpenedAt: Date

    var id: String { path }
}

struct DocumentAccessDescriptor {
    let fileURL: URL
    let directoryURL: URL
    let fileBookmarkData: Data?
    let supportFolderURL: URL?
    let supportFolderBookmarkData: Data?
    let supportAccessEntry: DocumentSupportAccessEntry?

    var recentEntry: RecentFileEntry {
        RecentFileEntry(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileBookmarkData: fileBookmarkData,
            lastOpenedAt: .now
        )
    }
}
