import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppLaunchCoordinator {
    private enum OpenRequestSource {
        case launch
        case panel
        case external
        case recent
        case reload
        case restore

        var shouldPromptForFolderTreeAccess: Bool {
            switch self {
            case .launch, .panel, .external:
                true
            case .recent, .reload, .restore:
                false
            }
        }
    }

    private let preferencesStore: PreferencesStore
    private let documentAccessController: DocumentAccessController
    private let markdownRenderer: MarkdownRenderer
    private let fileWatcher: FileWatcher

    let webBridge = ReaderWebBridge()

    var activeDocument: OpenedDocument?
    var loadErrorMessage: String?
    var isLoadingDocument = false
    var recentFiles: [RecentFileEntry]
    var authorizedFolders: [AuthorizedFolderEntry]
    var selectedAnchor: String?
    var fullDiskAccessStatus: FullDiskAccessStatus = .indeterminate
    private(set) var readerFontScale: Double

    private var currentDescriptor: DocumentAccessDescriptor?
    private var currentAccessSession: DocumentAccessSession?
    private var currentFileModificationDate: Date?
    private var loadTask: Task<Void, Never>?
    private var fullDiskAccessStatusTask: Task<Void, Never>?
    private var hasStarted = false
    private var hasRestoredWindowFrame = false
    private var hasResolvedFullDiskAccessStatus = false

    convenience init() {
        self.init(
            preferencesStore: PreferencesStore(),
            documentAccessController: DocumentAccessController(),
            markdownRenderer: MarkdownRenderer(),
            fileWatcher: FileWatcher()
        )
    }

    init(
        preferencesStore: PreferencesStore,
        documentAccessController: DocumentAccessController,
        markdownRenderer: MarkdownRenderer,
        fileWatcher: FileWatcher
    ) {
        self.preferencesStore = preferencesStore
        self.documentAccessController = documentAccessController
        self.markdownRenderer = markdownRenderer
        self.fileWatcher = fileWatcher
        self.recentFiles = preferencesStore.loadRecentFiles()
        self.authorizedFolders = preferencesStore.loadAuthorizedFolders()
        self.readerFontScale = preferencesStore.loadReaderFontScale()
    }

    var sidebarOutlineItems: [OutlineItem] {
        (activeDocument?.outlineItems ?? []).filter { $0.level <= 3 }
    }

    func start(skipRestore: Bool = false) {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        recentFiles = preferencesStore.loadRecentFiles()
        authorizedFolders = preferencesStore.loadAuthorizedFolders()
        preferencesStore.clearSystemWindowAutosaveArtifacts()
        restoreWindowFrameIfPossible()
        webBridge.setFontScale(readerFontScale)

        if let testFileURL = RuntimeEnvironment.launchTestFileURL() {
            open(
                descriptor: documentAccessController.prepareAccess(
                    for: testFileURL,
                    authorizedFolders: authorizedFolders
                ),
                source: .external,
                updateRecentFiles: false,
                persistLastOpen: false
            )
            return
        }

        if skipRestore == false {
            restoreLastDocumentIfNeeded()
        }
    }

    func openDocumentFromPanel() {
        guard let url = documentAccessController.openPanelPickDocumentURL(startingDirectory: activeDocument?.directoryURL) else {
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
        open(
            descriptor: documentAccessController.resolveRecentFile(entry),
            source: .recent,
            updateRecentFiles: true,
            persistLastOpen: true
        )
    }

    func restoreLastDocumentIfNeeded() {
        guard let record = preferencesStore.loadLastOpen() else {
            return
        }

        open(
            descriptor: documentAccessController.resolveLastOpen(record),
            source: .restore,
            updateRecentFiles: false,
            persistLastOpen: false
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

    func addAuthorizedFolderFromPanel() {
        let suggestedDirectory = activeDocument?.directoryURL
            ?? authorizedFolders.first.map { URL(fileURLWithPath: $0.path, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser

        let message = "Choose a durable root folder to authorize. OpenNow will reuse access for Markdown files and relative assets inside that folder tree."
        guard let folder = documentAccessController.openPanelPickFolder(
            suggestedDirectory: suggestedDirectory,
            message: message
        ) else {
            return
        }

        saveAuthorizedFolder(folder)
    }

    func removeAuthorizedFolder(_ entry: AuthorizedFolderEntry) {
        preferencesStore.removeAuthorizedFolder(path: entry.path)
        authorizedFolders = preferencesStore.loadAuthorizedFolders()
    }

    func refreshFullDiskAccessStatusIfNeeded() {
        guard hasResolvedFullDiskAccessStatus == false else {
            return
        }

        refreshFullDiskAccessStatus()
    }

    func refreshFullDiskAccessStatus() {
        fullDiskAccessStatusTask?.cancel()
        let documentAccessController = self.documentAccessController

        fullDiskAccessStatusTask = Task { [weak self] in
            let status = await Task.detached(priority: .utility) {
                documentAccessController.detectFullDiskAccessStatus()
            }.value

            guard let self, Task.isCancelled == false else {
                return
            }

            self.fullDiskAccessStatus = status
            self.hasResolvedFullDiskAccessStatus = true
        }
    }

    func openFullDiskAccessSettings() {
        let deepLinks = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]

        for value in deepLinks {
            guard let url = URL(string: value) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                return
            }
        }

        openSystemSettings()
    }

    func openSystemSettings() {
        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(systemSettingsURL)
    }

    func configureWindow(_ window: NSWindow) {
        window.minSize = NSSize(width: 620, height: 420)
    }

    func updateWindowFrame(window: NSWindow, frame: CGRect) {
        guard shouldPersistWindowFrame(window: window) else {
            return
        }

        preferencesStore.saveWindowFrame(frame)
    }

    private func openDocument(at url: URL, source: OpenRequestSource) {
        if source.shouldPromptForFolderTreeAccess,
           documentAccessController.authorizedFolder(containing: url, authorizedFolders: authorizedFolders) == nil,
           documentAccessController.documentContainsRelativeImages(at: url),
           let folder = promptForFolderTreeAccess(for: url) {
            saveAuthorizedFolder(folder)
        }

        open(
            descriptor: documentAccessController.prepareAccess(for: url, authorizedFolders: authorizedFolders),
            source: source,
            updateRecentFiles: true,
            persistLastOpen: true
        )
    }

    private func open(
        descriptor: DocumentAccessDescriptor,
        source: OpenRequestSource,
        updateRecentFiles: Bool,
        persistLastOpen: Bool
    ) {
        cancelPendingLoad()
        isLoadingDocument = true
        loadErrorMessage = nil
        selectedAnchor = nil

        currentAccessSession?.stop()
        ReaderAssetSecurityScopeStore.shared.clear()
        let accessSession = documentAccessController.startAccess(for: descriptor)
        currentAccessSession = accessSession
        ReaderAssetSecurityScopeStore.shared.replaceAuthorizedDirectories(
            accessSession.accessRootGranted ? [accessSession.accessRootURL] : []
        )
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
                self.loadErrorMessage = nil
                self.webBridge.setFontScale(self.readerFontScale)

                if updateRecentFiles {
                    self.preferencesStore.saveRecentFile(descriptor.recentEntry)
                    self.recentFiles = self.preferencesStore.loadRecentFiles()
                }

                if persistLastOpen {
                    self.preferencesStore.saveLastOpen(descriptor.lastOpenRecord)
                }

                self.attachFileWatcher(for: descriptor)
            } catch is CancellationError {
            } catch {
                self.isLoadingDocument = false
                self.activeDocument = nil
                self.currentDescriptor = nil
                self.currentFileModificationDate = nil
                self.fileWatcher.stop()
                self.currentAccessSession?.stop()
                self.currentAccessSession = nil
                ReaderAssetSecurityScopeStore.shared.clear()

                if source == .restore || source == .launch {
                    if source == .restore {
                        self.preferencesStore.saveLastOpen(nil)
                    }
                    self.loadErrorMessage = nil
                    return
                }

                self.loadErrorMessage = "Failed to open \(descriptor.fileURL.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    private func loadDocument(using descriptor: DocumentAccessDescriptor) async throws -> OpenedDocument {
        let markdownRenderer = self.markdownRenderer
        let loadedDocument = try await Task.detached(priority: .userInitiated) { [markdownRenderer] in
            try Self.readDocument(descriptor: descriptor, markdownRenderer: markdownRenderer)
        }.value

        return loadedDocument
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
            updateRecentFiles: false,
            persistLastOpen: false
        )
    }

    private func restoreWindowFrameIfPossible() {
        guard hasRestoredWindowFrame == false else {
            return
        }

        guard let frame = preferencesStore.loadWindowFrame(),
              let window = NSApplication.shared.windows.first
        else {
            return
        }

        guard let sanitizedFrame = sanitizedWindowFrame(frame, for: window) else {
            preferencesStore.clearWindowFrame()
            return
        }

        hasRestoredWindowFrame = true

        if sanitizedFrame.equalTo(frame) == false {
            preferencesStore.saveWindowFrame(sanitizedFrame)
        }

        window.setFrame(sanitizedFrame, display: true)
    }

    private func sanitizedWindowFrame(_ frame: CGRect, for window: NSWindow) -> CGRect? {
        guard frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.size.width.isFinite,
              frame.size.height.isFinite,
              frame.width > 0,
              frame.height > 0
        else {
            return nil
        }

        let visibleFrame = window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? frame

        let minWidth: CGFloat = 620
        let minHeight: CGFloat = 420
        let maxWidth = max(minWidth, visibleFrame.width * 0.94)
        let maxHeight = max(minHeight, visibleFrame.height * 0.82)
        let width = min(max(frame.width, minWidth), maxWidth)
        let height = min(max(frame.height, minHeight), maxHeight)
        let maxX = visibleFrame.maxX - width
        let maxY = visibleFrame.maxY - height
        var x = min(max(frame.minX, visibleFrame.minX), maxX)
        var y = min(max(frame.minY, visibleFrame.minY), maxY)

        if frame.width > maxWidth {
            x = visibleFrame.minX + (visibleFrame.width - width) / 2
        }

        if frame.height > maxHeight {
            y = visibleFrame.minY + (visibleFrame.height - height) / 2
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func shouldPersistWindowFrame(window: NSWindow) -> Bool {
        guard window.isMiniaturized == false else {
            return false
        }

        if window.styleMask.contains(.fullScreen) || window.isZoomed {
            return false
        }

        return true
    }

    private func promptForFolderTreeAccess(for fileURL: URL) -> AuthorizedFolderEntry? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Authorize a Folder Tree?"
        let preferredRootURL = documentAccessController.inferredAuthorizationRoot(for: fileURL)
        alert.informativeText = "This Markdown file references relative assets. OpenNow needs a durable root-folder bookmark so sibling images and future files in the same tree keep working. Suggested root: \(preferredRootURL.path)"
        alert.addButton(withTitle: "Authorize Root…")
        alert.addButton(withTitle: "Open File Only")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return documentAccessController.requestFolderTreeAccess(for: fileURL)
    }

    private func saveAuthorizedFolder(_ entry: AuthorizedFolderEntry) {
        preferencesStore.saveAuthorizedFolder(entry)
        authorizedFolders = preferencesStore.loadAuthorizedFolders()
    }

    private func setReaderFontScale(_ scale: Double) {
        let clampedScale = min(max(scale, 0.85), 1.8)
        readerFontScale = clampedScale
        preferencesStore.saveReaderFontScale(clampedScale)
        webBridge.setFontScale(clampedScale)
    }

}
