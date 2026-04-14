import Foundation
import OSLog
import UniformTypeIdentifiers

final class DocumentAccessController {
    private let logger = Logger(subsystem: "com.dahengchen.OpenNow", category: "DocumentAccess")

    func inferredAuthorizationRoot(for fileURL: URL) -> URL {
        let standardizedFileURL = fileURL.standardizedFileURL
        let documentDirectoryURL = standardizedFileURL.deletingLastPathComponent()
        let components = documentDirectoryURL.pathComponents

        if components.count >= 4, components[1] == "Users" {
            return URL(
                fileURLWithPath: "/Users/\(components[2])/\(components[3])",
                isDirectory: true
            ).standardizedFileURL
        }

        if components.count >= 3, components[1] == "Volumes" {
            return URL(fileURLWithPath: "/Volumes/\(components[2])", isDirectory: true).standardizedFileURL
        }

        if components.count >= 2 {
            return URL(fileURLWithPath: "/\(components[1])", isDirectory: true).standardizedFileURL
        }

        return documentDirectoryURL
    }

    func prepareAccess(
        for url: URL,
        documentSupportAccessEntries: [DocumentSupportAccessEntry]
    ) -> DocumentAccessDescriptor {
        let sourceURL = url
        let fileURL = sourceURL.standardizedFileURL
        let supportAccessEntry = matchingDocumentSupportAccess(
            for: fileURL,
            entries: documentSupportAccessEntries
        )

        let descriptor = DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: fileURL.deletingLastPathComponent(),
            fileBookmarkData: makeBookmark(for: sourceURL),
            supportFolderURL: supportAccessEntry.flatMap(resolveDocumentSupportFolderURL),
            supportFolderBookmarkData: supportAccessEntry?.supportFolderBookmarkData,
            supportAccessEntry: supportAccessEntry
        )

        logger.notice(
            "prepareAccess file=\(fileURL.path, privacy: .public) fileBookmark=\(descriptor.fileBookmarkData != nil) supportFolder=\(descriptor.supportFolderURL?.path ?? "<none>", privacy: .public)"
        )

        return descriptor
    }

    func resolveRecentFile(
        _ entry: RecentFileEntry,
        documentSupportAccessEntries: [DocumentSupportAccessEntry]
    ) -> DocumentAccessDescriptor {
        let fileURL = resolveBookmark(entry.fileBookmarkData) ?? URL(fileURLWithPath: entry.path)
        let supportAccessEntry = matchingDocumentSupportAccess(
            for: fileURL,
            entries: documentSupportAccessEntries
        )

        let descriptor = DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: fileURL.deletingLastPathComponent(),
            fileBookmarkData: entry.fileBookmarkData,
            supportFolderURL: supportAccessEntry.flatMap(resolveDocumentSupportFolderURL),
            supportFolderBookmarkData: supportAccessEntry?.supportFolderBookmarkData,
            supportAccessEntry: supportAccessEntry
        )

        logger.notice(
            "resolveRecent file=\(entry.path, privacy: .public) fileBookmark=\(entry.fileBookmarkData != nil) supportFolder=\(descriptor.supportFolderURL?.path ?? "<none>", privacy: .public)"
        )

        return descriptor
    }

    func matchingDocumentSupportAccess(
        for documentURL: URL,
        entries: [DocumentSupportAccessEntry]
    ) -> DocumentSupportAccessEntry? {
        let standardizedDocumentURL = documentURL.standardizedFileURL

        if let exactPathMatch = entries.first(where: { $0.documentPath == standardizedDocumentURL.path }) {
            return exactPathMatch
        }

        return entries.first { entry in
            guard let resolvedDocumentURL = resolveDocumentURL(for: entry) else {
                return false
            }

            return resolvedDocumentURL == standardizedDocumentURL
        }
    }

    func resolveDocumentSupportFolderURL(_ entry: DocumentSupportAccessEntry) -> URL? {
        let documentURL = resolveDocumentURL(for: entry)
            ?? URL(fileURLWithPath: entry.documentPath)

        return resolveBookmark(entry.supportFolderBookmarkData, relativeTo: documentURL)
            ?? URL(fileURLWithPath: entry.supportFolderPath, isDirectory: true).standardizedFileURL
    }

    func makeDocumentSupportAccessEntry(
        documentURL: URL,
        supportFolderURL: URL
    ) -> DocumentSupportAccessEntry {
        let standardizedDocumentURL = documentURL.standardizedFileURL
        let standardizedSupportFolderURL = supportFolderURL.standardizedFileURL

        return DocumentSupportAccessEntry(
            documentPath: standardizedDocumentURL.path,
            documentBookmarkData: makeBookmark(for: standardizedDocumentURL),
            supportFolderPath: standardizedSupportFolderURL.path,
            supportFolderBookmarkData: makeDocumentScopedBookmark(
                for: standardizedSupportFolderURL,
                relativeTo: standardizedDocumentURL
            ) ?? makeBookmark(for: standardizedSupportFolderURL),
            lastResolvedAt: .now
        )
    }

    func preferredSupportFolder(
        for unresolvedAssetURLs: [URL],
        documentDirectoryURL: URL
    ) -> URL {
        let normalizedAssets = unresolvedAssetURLs.map(\.standardizedFileURL)

        if let commonAncestor = commonAncestor(for: normalizedAssets) {
            return commonAncestor
        }

        let documentDirectory = documentDirectoryURL.standardizedFileURL
        let documentParent = documentDirectory.deletingLastPathComponent()

        if normalizedAssets.isEmpty == false {
            let firstAssetFolder = normalizedAssets[0].deletingLastPathComponent()
            if contains(firstAssetFolder, within: documentParent) || contains(documentParent, within: firstAssetFolder) {
                return firstAssetFolder
            }
        }

        if documentParent.path != documentDirectory.path {
            return documentParent
        }

        return inferredAuthorizationRoot(for: documentDirectory)
    }

    func isValidSupportFolderSelection(
        _ selectedFolderURL: URL,
        for unresolvedAssetURLs: [URL]
    ) -> Bool {
        let standardizedFolderURL = selectedFolderURL.standardizedFileURL
        return unresolvedAssetURLs.allSatisfy { assetURL in
            contains(assetURL.standardizedFileURL, within: standardizedFolderURL)
        }
    }

    func migrateLegacyAuthorizedFolders(
        _ authorizedFolders: [AuthorizedFolderEntry],
        recentFiles: [RecentFileEntry]
    ) -> [DocumentSupportAccessEntry] {
        guard authorizedFolders.isEmpty == false, recentFiles.isEmpty == false else {
            return []
        }

        let resolvedAuthorizedFolders = authorizedFolders.compactMap { entry -> (AuthorizedFolderEntry, URL)? in
            guard let folderURL = resolveAuthorizedFolderURL(entry) else {
                return nil
            }

            return (entry, folderURL)
        }

        var migratedEntries: [DocumentSupportAccessEntry] = []

        for recentFile in recentFiles {
            let documentURL = resolveBookmark(recentFile.fileBookmarkData)
                ?? URL(fileURLWithPath: recentFile.path).standardizedFileURL

            guard let matchingRoot = resolvedAuthorizedFolders
                .filter({ contains(documentURL, within: $0.1) })
                .max(by: { $0.1.path.count < $1.1.path.count }) else {
                continue
            }

            migratedEntries.append(
                DocumentSupportAccessEntry(
                    documentPath: documentURL.path,
                    documentBookmarkData: recentFile.fileBookmarkData,
                    supportFolderPath: matchingRoot.1.path,
                    supportFolderBookmarkData: matchingRoot.0.bookmarkData,
                    lastResolvedAt: .now
                )
            )
        }

        return uniqueDocumentSupportAccessEntries(migratedEntries)
    }

    func resolveBookmark(_ bookmarkData: Data?, relativeTo url: URL? = nil) -> URL? {
        guard let bookmarkData else {
            return nil
        }

        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: url,
            bookmarkDataIsStale: &isStale
        )
    }

    func makeBookmark(for url: URL) -> Data? {
        let data = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        logger.notice("makeBookmark url=\(url.path, privacy: .public) success=\(data != nil)")
        return data
    }

    func makeDocumentScopedBookmark(for url: URL, relativeTo documentURL: URL) -> Data? {
        let data = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: documentURL
        )

        logger.notice(
            "makeDocumentScopedBookmark url=\(url.path, privacy: .public) relativeTo=\(documentURL.path, privacy: .public) success=\(data != nil)"
        )
        return data
    }

    func startAccess(for descriptor: DocumentAccessDescriptor) -> DocumentAccessSession {
        let fileURL = resolveBookmark(descriptor.fileBookmarkData) ?? descriptor.fileURL
        let supportFolderURL = descriptor.supportAccessEntry.flatMap(resolveDocumentSupportFolderURL)
            ?? resolveBookmark(descriptor.supportFolderBookmarkData, relativeTo: fileURL)
            ?? descriptor.supportFolderURL

        let session = DocumentAccessSession(
            fileURL: fileURL,
            supportFolderURL: supportFolderURL
        )
        session.start()
        logger.notice(
            "startAccess file=\(fileURL.path, privacy: .public) supportFolder=\(supportFolderURL?.path ?? "<none>", privacy: .public) supportGranted=\(session.supportFolderAccessGranted) fileGranted=\(session.fileAccessGranted)"
        )
        return session
    }

    private func resolveAuthorizedFolderURL(_ entry: AuthorizedFolderEntry) -> URL? {
        resolveBookmark(entry.bookmarkData)
            ?? URL(fileURLWithPath: entry.path, isDirectory: true).standardizedFileURL
    }

    private func resolveDocumentURL(for entry: DocumentSupportAccessEntry) -> URL? {
        resolveBookmark(entry.documentBookmarkData)
            ?? URL(fileURLWithPath: entry.documentPath).standardizedFileURL
    }

    private func commonAncestor(for urls: [URL]) -> URL? {
        guard let firstURL = urls.first?.standardizedFileURL else {
            return nil
        }

        var ancestorComponents = firstURL.deletingLastPathComponent().pathComponents

        for url in urls.dropFirst() {
            let pathComponents = url.standardizedFileURL.deletingLastPathComponent().pathComponents
            var matchedComponents: [String] = []

            for (left, right) in zip(ancestorComponents, pathComponents) {
                guard left == right else {
                    break
                }

                matchedComponents.append(left)
            }

            ancestorComponents = matchedComponents
            if ancestorComponents.isEmpty {
                return nil
            }
        }

        let ancestorPath = NSString.path(withComponents: ancestorComponents)
        guard ancestorPath.isEmpty == false else {
            return nil
        }

        return URL(fileURLWithPath: ancestorPath, isDirectory: true).standardizedFileURL
    }

    private func uniqueDocumentSupportAccessEntries(
        _ entries: [DocumentSupportAccessEntry]
    ) -> [DocumentSupportAccessEntry] {
        var seenDocumentPaths = Set<String>()
        var uniqueEntries: [DocumentSupportAccessEntry] = []

        for entry in entries {
            guard seenDocumentPaths.insert(entry.documentPath).inserted else {
                continue
            }

            uniqueEntries.append(entry)
        }

        return uniqueEntries
    }

    private func contains(_ descendantURL: URL, within ancestorURL: URL) -> Bool {
        let descendantComponents = descendantURL.standardizedFileURL.pathComponents
        let ancestorComponents = ancestorURL.standardizedFileURL.pathComponents
        return descendantComponents.starts(with: ancestorComponents)
    }
}

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "com.dahengchen.opennow.markdown")
    }
}

final class DocumentAccessSession {
    let fileURL: URL
    let supportFolderURL: URL?
    private var activeURLs: [URL] = []
    private(set) var supportFolderAccessGranted = false
    private(set) var fileAccessGranted = false

    init(fileURL: URL, supportFolderURL: URL?) {
        self.fileURL = fileURL
        self.supportFolderURL = supportFolderURL
    }

    func start() {
        if let supportFolderURL,
           supportFolderURL.startAccessingSecurityScopedResource() {
            supportFolderAccessGranted = true
            activeURLs.append(supportFolderURL)
        }

        if activeURLs.contains(fileURL) == false,
           fileURL.startAccessingSecurityScopedResource() {
            fileAccessGranted = true
            activeURLs.append(fileURL)
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
