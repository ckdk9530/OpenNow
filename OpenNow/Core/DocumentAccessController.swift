import AppKit
import Foundation
import UniformTypeIdentifiers

final class DocumentAccessController {
    func openPanelPickDocument() -> DocumentAccessDescriptor? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.markdown, .plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return prepareAccess(for: url)
    }

    func prepareAccess(for url: URL) -> DocumentAccessDescriptor {
        let fileURL = url.standardizedFileURL
        let directoryURL = fileURL.deletingLastPathComponent()

        return DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: directoryURL,
            fileBookmarkData: makeBookmark(for: fileURL),
            directoryBookmarkData: makeBookmark(for: directoryURL)
        )
    }

    func resolveRecentFile(_ entry: RecentFileEntry) -> DocumentAccessDescriptor? {
        resolve(
            path: entry.path,
            fileBookmarkData: entry.fileBookmarkData,
            directoryBookmarkData: entry.directoryBookmarkData
        )
    }

    func resolveLastOpen(_ record: LastOpenRecord) -> DocumentAccessDescriptor? {
        resolve(
            path: record.path,
            fileBookmarkData: record.fileBookmarkData,
            directoryBookmarkData: record.directoryBookmarkData
        )
    }

    func makeBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    func startAccess(for descriptor: DocumentAccessDescriptor) -> DocumentAccessSession {
        let fileURL = resolveBookmarkIfPossible(descriptor.fileBookmarkData) ?? descriptor.fileURL
        let directoryURL = resolveBookmarkIfPossible(descriptor.directoryBookmarkData) ?? descriptor.directoryURL
        let session = DocumentAccessSession(urls: [directoryURL, fileURL])
        session.start()
        return session
    }

    private func resolve(
        path: String,
        fileBookmarkData: Data?,
        directoryBookmarkData: Data?
    ) -> DocumentAccessDescriptor {
        let fileURL = resolveBookmarkIfPossible(fileBookmarkData) ?? URL(fileURLWithPath: path)
        let directoryURL = resolveBookmarkIfPossible(directoryBookmarkData) ?? fileURL.deletingLastPathComponent()

        return DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: directoryURL,
            fileBookmarkData: fileBookmarkData,
            directoryBookmarkData: directoryBookmarkData
        )
    }

    private func resolveBookmarkIfPossible(_ bookmarkData: Data?) -> URL? {
        guard let bookmarkData else {
            return nil
        }

        return resolveBookmark(bookmarkData)
    }
}

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "com.dahengchen.opennow.markdown")
    }
}

final class DocumentAccessSession {
    private let urls: [URL]
    private var activeURLs: [URL] = []

    init(urls: [URL]) {
        self.urls = urls
    }

    func start() {
        for url in urls where url.startAccessingSecurityScopedResource() {
            activeURLs.append(url)
        }
    }

    func stop() {
        for url in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }

        activeURLs.removeAll()
    }

    deinit {
        stop()
    }
}
