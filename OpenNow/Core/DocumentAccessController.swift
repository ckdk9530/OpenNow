import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

final class DocumentAccessController {
    private let logger = Logger(subsystem: "com.dahengchen.OpenNow", category: "DocumentAccess")

    func openPanelPickDocumentURL(startingDirectory: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.markdown]
        panel.directoryURL = startingDirectory

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func openPanelPickFolder(
        suggestedDirectory: URL? = nil,
        message: String? = nil
    ) -> AuthorizedFolderEntry? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.directoryURL = suggestedDirectory
        panel.message = message ?? "Choose a folder tree to authorize. OpenNow will reuse this access for Markdown files and relative assets inside that folder and its subfolders."
        panel.prompt = "Use Folder"

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return nil
        }

        return makeAuthorizedFolderEntry(for: folderURL)
    }

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

    func requestFolderTreeAccess(for fileURL: URL) -> AuthorizedFolderEntry? {
        let standardizedFileURL = fileURL.standardizedFileURL
        let preferredRootURL = inferredAuthorizationRoot(for: standardizedFileURL)

        while true {
            let message = """
            Choose a durable access root for this Markdown file. OpenNow expects the tree root, not a nested child folder, so sibling images and future files under the same root keep working.
            Suggested root: \(preferredRootURL.path)
            """

            guard let entry = openPanelPickFolder(
                suggestedDirectory: preferredRootURL,
                message: message
            ) else {
                return nil
            }

            let selectedRootURL = URL(fileURLWithPath: entry.path, isDirectory: true).standardizedFileURL
            if contains(preferredRootURL, within: selectedRootURL) {
                return entry
            }

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Choose the suggested root or one of its parent folders."
            alert.informativeText = "\(standardizedFileURL.lastPathComponent) should be authorized from \(preferredRootURL.path), not from a narrower child folder."
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Cancel")

            guard alert.runModal() == .alertFirstButtonReturn else {
                return nil
            }
        }
    }

    func prepareAccess(
        for url: URL,
        authorizedFolders: [AuthorizedFolderEntry]
    ) -> DocumentAccessDescriptor {
        let sourceURL = url
        let fileURL = sourceURL.standardizedFileURL
        let directoryURL = fileURL.deletingLastPathComponent()
        let accessRootEntry = authorizedFolder(containing: fileURL, authorizedFolders: authorizedFolders)

        let descriptor = DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: directoryURL,
            fileBookmarkData: makeBookmark(for: sourceURL),
            accessRootURL: resolveAuthorizedFolderURL(accessRootEntry),
            directoryBookmarkData: accessRootEntry?.bookmarkData
        )

        logger.notice(
            "prepareAccess file=\(fileURL.path, privacy: .public) fileBookmark=\(descriptor.fileBookmarkData != nil) accessRoot=\(descriptor.accessRootURL?.path ?? "<none>", privacy: .public) dirBookmark=\(descriptor.directoryBookmarkData != nil)"
        )

        return descriptor
    }

    func resolveRecentFile(
        _ entry: RecentFileEntry,
        authorizedFolders: [AuthorizedFolderEntry]
    ) -> DocumentAccessDescriptor {
        let descriptor = resolve(
            path: entry.path,
            fileBookmarkData: entry.fileBookmarkData,
            directoryBookmarkData: entry.directoryBookmarkData,
            accessRootPath: entry.accessRootPath,
            authorizedFolders: authorizedFolders
        )

        logger.notice(
            "resolveRecent file=\(entry.path, privacy: .public) storedFileBookmark=\(entry.fileBookmarkData != nil) storedDirBookmark=\(entry.directoryBookmarkData != nil) resolvedAccessRoot=\(descriptor.accessRootURL?.path ?? "<none>", privacy: .public)"
        )

        return descriptor
    }

    func authorizedFolder(
        containing fileURL: URL,
        authorizedFolders: [AuthorizedFolderEntry]
    ) -> AuthorizedFolderEntry? {
        let standardizedFileURL = fileURL.standardizedFileURL

        return authorizedFolders
            .compactMap { entry -> (AuthorizedFolderEntry, URL)? in
                guard let rootURL = resolveAuthorizedFolderURL(entry) else {
                    return nil
                }

                return (entry, rootURL)
            }
            .filter { contains(standardizedFileURL, within: $0.1) }
            .max { lhs, rhs in
                lhs.1.path.count < rhs.1.path.count
            }?
            .0
    }

    func makeAuthorizedFolderEntry(for url: URL) -> AuthorizedFolderEntry {
        let sourceURL = url
        let folderURL = sourceURL.standardizedFileURL
        return AuthorizedFolderEntry(
            path: folderURL.path,
            displayName: folderURL.lastPathComponent,
            bookmarkData: makeBookmark(for: sourceURL),
            lastUsedAt: .now
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
        let accessRootURL = resolveBookmarkIfPossible(descriptor.directoryBookmarkData)
            ?? descriptor.accessRootURL
            ?? descriptor.directoryURL

        let session = DocumentAccessSession(accessRootURL: accessRootURL, fileURL: fileURL)
        session.start()
        logger.notice(
            "startAccess file=\(fileURL.path, privacy: .public) accessRoot=\(accessRootURL.path, privacy: .public) accessRootGranted=\(session.accessRootGranted) fileGranted=\(session.fileAccessGranted)"
        )
        return session
    }

    func documentContainsRelativeImages(at fileURL: URL) -> Bool {
        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return false
        }

        let patterns = [
            #"!\[[^\]]*\]\(([^)]+)\)"#,
            #"<img[^>]+src=["']([^"']+)["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
            for match in regex.matches(in: markdown, range: range) {
                guard match.numberOfRanges >= 2,
                      let captureRange = Range(match.range(at: 1), in: markdown)
                else {
                    continue
                }

                let captured = markdown[captureRange]
                    .split(separator: " ", maxSplits: 1)
                    .first
                    .map(String.init)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>")) ?? ""

                if isRelativePath(captured) {
                    return true
                }
            }
        }

        return false
    }

    private func resolve(
        path: String,
        fileBookmarkData: Data?,
        directoryBookmarkData: Data?,
        accessRootPath: String?,
        authorizedFolders: [AuthorizedFolderEntry]
    ) -> DocumentAccessDescriptor {
        let fileURL = resolveBookmarkIfPossible(fileBookmarkData) ?? URL(fileURLWithPath: path)
        let directoryURL = fileURL.deletingLastPathComponent()
        let accessRootEntry = authorizedFolder(containing: fileURL, authorizedFolders: authorizedFolders)
        let accessRootURL = resolveAuthorizedFolderURL(accessRootEntry)
            ?? resolveBookmarkIfPossible(directoryBookmarkData)
            ?? accessRootPath.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }

        return DocumentAccessDescriptor(
            fileURL: fileURL,
            directoryURL: directoryURL,
            fileBookmarkData: fileBookmarkData,
            accessRootURL: accessRootURL,
            directoryBookmarkData: accessRootEntry?.bookmarkData ?? directoryBookmarkData
        )
    }

    private func resolveBookmarkIfPossible(_ bookmarkData: Data?) -> URL? {
        guard let bookmarkData else {
            return nil
        }

        return resolveBookmark(bookmarkData)
    }

    private func resolveAuthorizedFolderURL(_ entry: AuthorizedFolderEntry?) -> URL? {
        guard let entry else {
            return nil
        }

        return resolveBookmarkIfPossible(entry.bookmarkData)
            ?? URL(fileURLWithPath: entry.path, isDirectory: true).standardizedFileURL
    }

    private func contains(_ descendantURL: URL, within ancestorURL: URL) -> Bool {
        let descendantComponents = descendantURL.standardizedFileURL.pathComponents
        let ancestorComponents = ancestorURL.standardizedFileURL.pathComponents
        return descendantComponents.starts(with: ancestorComponents)
    }

    private func isRelativePath(_ value: String) -> Bool {
        guard value.isEmpty == false,
              value.hasPrefix("/") == false,
              value.hasPrefix("#") == false
        else {
            return false
        }

        if let url = URL(string: value), url.scheme != nil {
            return false
        }

        return true
    }
}

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "com.dahengchen.opennow.markdown")
    }
}

final class DocumentAccessSession {
    let accessRootURL: URL
    let fileURL: URL
    private var activeURLs: [URL] = []
    private(set) var accessRootGranted = false
    private(set) var fileAccessGranted = false

    init(accessRootURL: URL, fileURL: URL) {
        self.accessRootURL = accessRootURL
        self.fileURL = fileURL
    }

    func start() {
        if accessRootURL.startAccessingSecurityScopedResource() {
            accessRootGranted = true
            activeURLs.append(accessRootURL)
        }

        if fileURL != accessRootURL, fileURL.startAccessingSecurityScopedResource() {
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
