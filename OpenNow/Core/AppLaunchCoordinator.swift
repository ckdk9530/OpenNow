import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AppLaunchCoordinator {
    private enum OpenRequestSource: Equatable {
        case launch
        case panel
        case external
        case recent
        case reload

        var allowsOpenMarkdownPanelOnFailure: Bool {
            switch self {
            case .recent, .reload:
                true
            case .launch, .panel, .external:
                false
            }
        }
    }

    private let preferencesStore: PreferencesStore
    private let documentAccessController: DocumentAccessController
    private let markdownRenderer: MarkdownRenderer
    private let fileWatcher: FileWatcher
    private let panelPresenter: any DocumentPanelPresenting
    private let alertPresenter: any DocumentAlertPresenting
    private let windowChromeController: any WindowChromeControlling
    private let supportingFilesAccessCoordinator: SupportingFilesAccessCoordinator
    private let logger = Logger(subsystem: "com.dahengchen.OpenNow", category: "Launch")

    let webBridge = ReaderWebBridge()

    var activeDocument: OpenedDocument?
    var isLoadingDocument = false
    var recentFiles: [RecentFileEntry]
    var selectedAnchor: String?
    private(set) var readerFontScale: Double

    private var documentSupportAccessEntries: [DocumentSupportAccessEntry]
    private var currentDescriptor: DocumentAccessDescriptor?
    private var currentAccessSession: DocumentAccessSession?
    private var currentFileModificationDate: Date?
    private var loadTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        preferencesStore: PreferencesStore,
        documentAccessController: DocumentAccessController,
        markdownRenderer: MarkdownRenderer,
        fileWatcher: FileWatcher,
        panelPresenter: any DocumentPanelPresenting,
        alertPresenter: any DocumentAlertPresenting,
        windowChromeController: any WindowChromeControlling
    ) {
        self.preferencesStore = preferencesStore
        self.documentAccessController = documentAccessController
        self.markdownRenderer = markdownRenderer
        self.fileWatcher = fileWatcher
        self.panelPresenter = panelPresenter
        self.alertPresenter = alertPresenter
        self.windowChromeController = windowChromeController
        self.recentFiles = []
        self.readerFontScale = 1.0
        self.documentSupportAccessEntries = []
        self.supportingFilesAccessCoordinator = SupportingFilesAccessCoordinator(
            documentAccessController: documentAccessController,
            preferencesStore: preferencesStore,
            alertPresenter: alertPresenter
        )

        supportingFilesAccessCoordinator.documentStateDidChange = { [weak self] documentPath, state, unresolvedAssetURLs in
            guard let self,
                  let activeDocument = self.activeDocument,
                  activeDocument.url.standardizedFileURL.path == documentPath
            else {
                return
            }

            self.activeDocument = activeDocument.updatingSupportAccess(
                state: state,
                unresolvedLocalAssetURLs: unresolvedAssetURLs
            )
        }
        supportingFilesAccessCoordinator.entriesDidChange = { [weak self] entries in
            self?.documentSupportAccessEntries = entries
        }
        supportingFilesAccessCoordinator.accessDidRecover = { [weak self] documentPath in
            guard let self,
                  let activeDocument = self.activeDocument,
                  activeDocument.url.standardizedFileURL.path == documentPath
            else {
                return
            }

            self.webBridge.reloadPreservingScrollPosition()
        }

        ReaderAssetSecurityScopeStore.shared.setAuthorizationHandler { [weak self] assetURL in
            self?.requestSupportingFilesAccess(for: assetURL)
        }
    }

    var sidebarOutlineItems: [OutlineItem] {
        (activeDocument?.outlineItems ?? []).filter { $0.level <= 3 }
    }

    func start() {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        recentFiles = preferencesStore.loadRecentFiles()
        readerFontScale = preferencesStore.loadReaderFontScale()
        webBridge.setFontScale(readerFontScale)

        supportingFilesAccessCoordinator.loadPersistedEntries()
        supportingFilesAccessCoordinator.migrateLegacyAuthorizedFoldersIfNeeded(recentFiles: recentFiles)
        documentSupportAccessEntries = supportingFilesAccessCoordinator.entries

        windowChromeController.apply(document: activeDocument)

        if let testFileURL = RuntimeEnvironment.launchTestDocumentURL() {
            open(
                descriptor: documentAccessController.prepareAccess(
                    for: testFileURL,
                    documentSupportAccessEntries: documentSupportAccessEntries
                ),
                source: .external,
                updateRecentFiles: false
            )
        }
    }

    func openDocumentFromPanel() {
        guard let url = panelPresenter.pickDocumentURL(startingDirectory: activeDocument?.directoryURL) else {
            return
        }

        openDocument(at: url, source: .panel)
    }

    func openDocument(at url: URL) {
        openDocument(at: url, source: .external)
    }

    func openLaunchDocument(at url: URL) {
        openDocument(at: url, source: .launch)
    }

    func openRecent(_ entry: RecentFileEntry) {
        recentFiles = preferencesStore.loadRecentFiles()
        supportingFilesAccessCoordinator.loadPersistedEntries()
        documentSupportAccessEntries = supportingFilesAccessCoordinator.entries

        let resolvedEntry = recentFiles.first(where: { $0.path == entry.path }) ?? entry

        logger.notice(
            "openRecent file=\(resolvedEntry.path, privacy: .public) storedFileBookmark=\(resolvedEntry.fileBookmarkData != nil)"
        )
        open(
            descriptor: documentAccessController.resolveRecentFile(
                resolvedEntry,
                documentSupportAccessEntries: documentSupportAccessEntries
            ),
            source: .recent,
            updateRecentFiles: true
        )
    }

    func cancelPendingLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    func page(_ direction: ReaderPageDirection) {
        webBridge.page(direction)
    }

    func increaseReaderFontScale() {
        setReaderFontScale(readerFontScale + 0.1)
    }

    func decreaseReaderFontScale() {
        setReaderFontScale(readerFontScale - 0.1)
    }

    func resetReaderFontScale() {
        setReaderFontScale(1.0)
    }

    func jump(to item: OutlineItem) {
        selectedAnchor = item.anchor
        webBridge.jump(to: item.anchor)
    }

    func clearRecentFiles() {
        preferencesStore.clearRecentFiles()
        recentFiles = []
    }

    func closeCurrentFile() {
        cancelPendingLoad()
        isLoadingDocument = false
        selectedAnchor = nil
        if let documentURL = activeDocument?.url {
            supportingFilesAccessCoordinator.resetSession(for: documentURL)
        }
        activeDocument = nil
        currentDescriptor = nil
        currentFileModificationDate = nil
        fileWatcher.stop()
        currentAccessSession?.stop()
        currentAccessSession = nil
        ReaderAssetSecurityScopeStore.shared.clear()
        windowChromeController.apply(document: nil)
    }

    private func openDocument(at url: URL, source: OpenRequestSource) {
        logger.notice("openDocument source=\(String(describing: source), privacy: .public) file=\(url.path, privacy: .public)")

        open(
            descriptor: documentAccessController.prepareAccess(
                for: url,
                documentSupportAccessEntries: documentSupportAccessEntries
            ),
            source: source,
            updateRecentFiles: true
        )
    }

    private func requestSupportingFilesAccess(for assetURL: URL) -> URL? {
        guard RuntimeEnvironment.isRunningUnderXCTest() == false else {
            return nil
        }

        return supportingFilesAccessCoordinator.requestSupportAccess(
            for: activeDocument,
            failingAssetURL: assetURL
        )
    }

    private func open(
        descriptor: DocumentAccessDescriptor,
        source: OpenRequestSource,
        updateRecentFiles: Bool
    ) {
        logger.notice(
            "open source=\(String(describing: source), privacy: .public) file=\(descriptor.fileURL.path, privacy: .public) fileBookmark=\(descriptor.fileBookmarkData != nil) supportFolder=\(descriptor.supportFolderURL?.path ?? "<none>", privacy: .public)"
        )
        cancelPendingLoad()
        isLoadingDocument = true
        selectedAnchor = nil

        if source != .reload {
            supportingFilesAccessCoordinator.resetSession(for: descriptor.fileURL)
        }

        currentAccessSession?.stop()
        ReaderAssetSecurityScopeStore.shared.clear()

        let accessSession = documentAccessController.startAccess(for: descriptor)
        currentAccessSession = accessSession
        if accessSession.supportFolderAccessGranted,
           let supportFolderURL = accessSession.supportFolderURL {
            ReaderAssetSecurityScopeStore.shared.replaceAuthorizedDirectories([supportFolderURL])
        }

        currentDescriptor = descriptor
        fileWatcher.stop()

        loadTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else {
                return
            }

            do {
                let loadedDocument = try await self.loadDocument(using: descriptor)
                try Task.checkCancellation()

                self.activeDocument = loadedDocument
                self.currentFileModificationDate = loadedDocument.lastKnownModificationDate
                self.isLoadingDocument = false
                self.webBridge.setFontScale(self.readerFontScale)
                self.windowChromeController.apply(document: loadedDocument)

                if updateRecentFiles {
                    self.preferencesStore.saveRecentFile(descriptor.recentEntry)
                    self.recentFiles = self.preferencesStore.loadRecentFiles()
                    self.logger.notice(
                        "savedRecent file=\(descriptor.fileURL.path, privacy: .public) persistedFileBookmark=\(descriptor.recentEntry.fileBookmarkData != nil)"
                    )
                }

                self.attachFileWatcher(for: descriptor)
            } catch is CancellationError {
            } catch {
                let message = Self.makeLoadErrorMessage(
                    for: descriptor,
                    source: source,
                    error: error
                )
                self.logger.error(
                    "openFailed source=\(String(describing: source), privacy: .public) file=\(descriptor.fileURL.path, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
                self.isLoadingDocument = false
                self.activeDocument = nil
                self.currentDescriptor = nil
                self.currentFileModificationDate = nil
                self.fileWatcher.stop()
                self.currentAccessSession?.stop()
                self.currentAccessSession = nil
                ReaderAssetSecurityScopeStore.shared.clear()
                self.windowChromeController.apply(document: nil)

                guard source != .launch else {
                    return
                }

                let action = self.alertPresenter.presentLoadFailure(
                    message: message,
                    allowsOpenMarkdownPanel: source.allowsOpenMarkdownPanelOnFailure
                )

                if action == .openMarkdownPanel {
                    self.openDocumentFromPanel()
                }
            }
        }
    }

    private func loadDocument(using descriptor: DocumentAccessDescriptor) async throws -> OpenedDocument {
        let markdownRenderer = self.markdownRenderer
        return try await Task.detached(priority: .userInitiated) { [markdownRenderer] in
            try Self.readDocument(descriptor: descriptor, markdownRenderer: markdownRenderer)
        }.value
    }

    nonisolated private static func readDocument(
        descriptor: DocumentAccessDescriptor,
        markdownRenderer: MarkdownRenderer
    ) throws -> OpenedDocument {
        let resourceValues = try descriptor.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        let markdown = try String(contentsOf: descriptor.fileURL, encoding: .utf8)
        let rendered = try markdownRenderer.render(markdown: markdown, baseURL: descriptor.directoryURL)

        return OpenedDocument(
            url: descriptor.fileURL,
            directoryURL: descriptor.directoryURL,
            rawMarkdown: markdown,
            renderedHTML: rendered.html,
            outlineItems: rendered.outlineItems,
            relativeLocalAssetURLs: rendered.relativeLocalAssetURLs,
            unresolvedLocalAssetURLs: [],
            supportAccessState: .ready,
            lastKnownModificationDate: resourceValues.contentModificationDate
        )
    }

    private func attachFileWatcher(for descriptor: DocumentAccessDescriptor) {
        fileWatcher.start(url: descriptor.fileURL) { [weak self] in
            Task { @MainActor [weak self] in
                self?.reloadCurrentDocumentIfNeeded()
            }
        }
    }

    private func reloadCurrentDocumentIfNeeded() {
        guard let descriptor = currentDescriptor else {
            return
        }

        let modificationDate = try? descriptor.fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        guard modificationDate != currentFileModificationDate else {
            return
        }

        open(
            descriptor: descriptor,
            source: .reload,
            updateRecentFiles: false
        )
    }

    private func setReaderFontScale(_ scale: Double) {
        let clampedScale = min(max(scale, 0.85), 1.8)
        readerFontScale = clampedScale
        preferencesStore.saveReaderFontScale(clampedScale)
        webBridge.setFontScale(clampedScale)
    }

    private static func makeLoadErrorMessage(
        for descriptor: DocumentAccessDescriptor,
        source: OpenRequestSource,
        error: any Error
    ) -> String {
        let nsError = error as NSError
        let isPermissionFailure = nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError

        if isPermissionFailure, source == .recent || source == .reload {
            return "OpenNow no longer has permission to reopen \(descriptor.fileURL.lastPathComponent) from history. Open it once with Open Markdown… to refresh access."
        }

        return "Failed to open \(descriptor.fileURL.lastPathComponent): \(error.localizedDescription)"
    }
}
