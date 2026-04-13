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
}

struct OpenedDocument {
    let url: URL
    let directoryURL: URL
    let bookmarkData: Data?
    let rawMarkdown: String
    let renderedHTML: String
    let outlineItems: [OutlineItem]
    let lastKnownModificationDate: Date?
    let containsRelativeImages: Bool
}

struct RecentFileEntry: Identifiable, Codable, Equatable {
    let path: String
    let displayName: String
    let fileBookmarkData: Data?
    let directoryBookmarkData: Data?
    let lastOpenedAt: Date

    var id: String { path }
}

struct LastOpenRecord: Codable, Equatable {
    let path: String
    let displayName: String
    let fileBookmarkData: Data?
    let directoryBookmarkData: Data?
}

struct DocumentAccessDescriptor {
    let fileURL: URL
    let directoryURL: URL
    let fileBookmarkData: Data?
    let directoryBookmarkData: Data?

    var recentEntry: RecentFileEntry {
        RecentFileEntry(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileBookmarkData: fileBookmarkData,
            directoryBookmarkData: directoryBookmarkData,
            lastOpenedAt: .now
        )
    }

    var lastOpenRecord: LastOpenRecord {
        LastOpenRecord(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileBookmarkData: fileBookmarkData,
            directoryBookmarkData: directoryBookmarkData
        )
    }
}
