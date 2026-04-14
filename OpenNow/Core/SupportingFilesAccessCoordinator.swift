import Foundation

@MainActor
final class SupportingFilesAccessCoordinator {
    private let documentAccessController: DocumentAccessController
    private let preferencesStore: PreferencesStore
    private let alertPresenter: any DocumentAlertPresenting

    private var recoveringDocumentPaths = Set<String>()
    private var suppressedDocumentPaths = Set<String>()
    private var unavailableDocumentPaths = Set<String>()

    var entries: [DocumentSupportAccessEntry] = []
    var documentStateDidChange: ((String, SupportAccessState, [URL]) -> Void)?
    var entriesDidChange: (([DocumentSupportAccessEntry]) -> Void)?
    var accessDidRecover: ((String) -> Void)?

    init(
        documentAccessController: DocumentAccessController,
        preferencesStore: PreferencesStore,
        alertPresenter: any DocumentAlertPresenting
    ) {
        self.documentAccessController = documentAccessController
        self.preferencesStore = preferencesStore
        self.alertPresenter = alertPresenter
    }

    func loadPersistedEntries() {
        entries = preferencesStore.loadDocumentSupportAccess()
    }

    func migrateLegacyAuthorizedFoldersIfNeeded(recentFiles: [RecentFileEntry]) {
        guard entries.isEmpty else {
            return
        }

        let authorizedFolders = preferencesStore.loadAuthorizedFolders()
        guard authorizedFolders.isEmpty == false else {
            return
        }

        let migratedEntries = documentAccessController.migrateLegacyAuthorizedFolders(
            authorizedFolders,
            recentFiles: recentFiles
        )
        guard migratedEntries.isEmpty == false else {
            preferencesStore.clearAuthorizedFolders()
            return
        }

        entries = migratedEntries
        preferencesStore.replaceDocumentSupportAccess(migratedEntries)
        preferencesStore.clearAuthorizedFolders()
        entriesDidChange?(migratedEntries)
    }

    func resetSession(for documentURL: URL?) {
        guard let documentURL else {
            recoveringDocumentPaths.removeAll()
            suppressedDocumentPaths.removeAll()
            unavailableDocumentPaths.removeAll()
            return
        }

        let documentPath = documentURL.standardizedFileURL.path
        recoveringDocumentPaths.remove(documentPath)
        suppressedDocumentPaths.remove(documentPath)
        unavailableDocumentPaths.remove(documentPath)
    }

    func requestSupportAccess(
        for document: OpenedDocument?,
        failingAssetURL: URL
    ) -> URL? {
        guard let document else {
            return nil
        }

        let documentURL = document.url.standardizedFileURL
        let documentPath = documentURL.path

        guard suppressedDocumentPaths.contains(documentPath) == false,
              unavailableDocumentPaths.contains(documentPath) == false,
              recoveringDocumentPaths.contains(documentPath) == false
        else {
            return nil
        }

        let unresolvedAssetURLs = unresolvedAssetURLs(
            for: document,
            failingAssetURL: failingAssetURL
        )
        let suggestedDirectory = documentAccessController.preferredSupportFolder(
            for: unresolvedAssetURLs,
            documentDirectoryURL: document.directoryURL
        )

        recoveringDocumentPaths.insert(documentPath)
        documentStateDidChange?(documentPath, .recovering, unresolvedAssetURLs)
        defer { recoveringDocumentPaths.remove(documentPath) }

        while true {
            switch alertPresenter.recoverSupportingFilesAccess(
                for: documentURL,
                suggestedDirectory: suggestedDirectory,
                unresolvedAssetURLs: unresolvedAssetURLs
            ) {
            case let .selectedFolder(selectedFolderURL):
                if documentAccessController.isValidSupportFolderSelection(
                    selectedFolderURL,
                    for: unresolvedAssetURLs
                ) {
                    let entry = documentAccessController.makeDocumentSupportAccessEntry(
                        documentURL: documentURL,
                        supportFolderURL: selectedFolderURL
                    )
                    persist(entry)
                    suppressedDocumentPaths.remove(documentPath)
                    unavailableDocumentPaths.remove(documentPath)
                    documentStateDidChange?(documentPath, .ready, [])
                    accessDidRecover?(documentPath)
                    return documentAccessController.resolveDocumentSupportFolderURL(entry) ?? selectedFolderURL
                }

                guard alertPresenter.retrySupportingFilesSelection(
                    selectedDirectory: selectedFolderURL,
                    suggestedDirectory: suggestedDirectory,
                    unresolvedAssetURLs: unresolvedAssetURLs
                ) else {
                    unavailableDocumentPaths.insert(documentPath)
                    documentStateDidChange?(documentPath, .unavailable, unresolvedAssetURLs)
                    return nil
                }
            case .continueWithoutImages:
                suppressedDocumentPaths.insert(documentPath)
                documentStateDidChange?(documentPath, .suppressed, unresolvedAssetURLs)
                return nil
            case .unavailable:
                unavailableDocumentPaths.insert(documentPath)
                documentStateDidChange?(documentPath, .unavailable, unresolvedAssetURLs)
                return nil
            }
        }
    }

    private func unresolvedAssetURLs(
        for document: OpenedDocument,
        failingAssetURL: URL
    ) -> [URL] {
        var unresolved = document.relativeLocalAssetURLs
        if unresolved.isEmpty {
            unresolved = document.unresolvedLocalAssetURLs
        }

        if unresolved.contains(failingAssetURL.standardizedFileURL) == false {
            unresolved.append(failingAssetURL.standardizedFileURL)
        }

        var seenPaths = Set<String>()
        return unresolved.compactMap { url in
            let standardizedURL = url.standardizedFileURL
            guard seenPaths.insert(standardizedURL.path).inserted else {
                return nil
            }
            return standardizedURL
        }
    }

    private func persist(_ entry: DocumentSupportAccessEntry) {
        entries.removeAll { $0.documentPath == entry.documentPath }
        entries.insert(entry, at: 0)
        preferencesStore.saveDocumentSupportAccess(entry)
        entriesDidChange?(entries)
    }
}
