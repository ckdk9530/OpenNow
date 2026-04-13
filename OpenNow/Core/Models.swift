import Foundation

enum ReaderPageDirection {
    case up
    case down
}

enum FullDiskAccessStatus: Equatable {
    case likelyEnabled
    case notDetected
    case indeterminate
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

struct OpenedDocument {
    let url: URL
    let directoryURL: URL
    let rawMarkdown: String
    let renderedHTML: String
    let outlineItems: [OutlineItem]
    let lastKnownModificationDate: Date?
}

struct AuthorizedFolderEntry: Identifiable, Codable, Equatable {
    let path: String
    let displayName: String
    let bookmarkData: Data?
    let lastUsedAt: Date

    var id: String { path }
}

struct RecentFileEntry: Identifiable, Codable, Equatable {
    let path: String
    let displayName: String
    let fileBookmarkData: Data?
    let directoryBookmarkData: Data?
    let accessRootPath: String?
    let lastOpenedAt: Date

    var id: String { path }
}

struct LastOpenRecord: Codable, Equatable {
    let path: String
    let displayName: String
    let fileBookmarkData: Data?
    let directoryBookmarkData: Data?
    let accessRootPath: String?
}

struct DocumentAccessDescriptor {
    let fileURL: URL
    let directoryURL: URL
    let fileBookmarkData: Data?
    let accessRootURL: URL?
    let directoryBookmarkData: Data?

    var recentEntry: RecentFileEntry {
        RecentFileEntry(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileBookmarkData: fileBookmarkData,
            directoryBookmarkData: directoryBookmarkData,
            accessRootPath: accessRootURL?.path,
            lastOpenedAt: .now
        )
    }

    var lastOpenRecord: LastOpenRecord {
        LastOpenRecord(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileBookmarkData: fileBookmarkData,
            directoryBookmarkData: directoryBookmarkData,
            accessRootPath: accessRootURL?.path
        )
    }
}
