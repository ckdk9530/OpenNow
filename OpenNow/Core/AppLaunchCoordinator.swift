import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppLaunchCoordinator {
    private let preferencesStore: PreferencesStore
    private let documentAccessController: DocumentAccessController
    private let markdownRenderer: MarkdownRenderer
    private let fileWatcher: FileWatcher

    let webBridge = ReaderWebBridge()

    var activeDocument: OpenedDocument?
    var loadErrorMessage: String?
    var noticeMessage: String?
    var isLoadingDocument = false
    var recentFiles: [RecentFileEntry]
    var selectedAnchor: String?

    private var currentDescriptor: DocumentAccessDescriptor?
    private var currentAccessSession: DocumentAccessSession?
    private var currentFileModificationDate: Date?
    private var loadTask: Task<Void, Never>?
    private var hasStarted = false

    init(
        preferencesStore: PreferencesStore = PreferencesStore(),
        documentAccessController: DocumentAccessController = DocumentAccessController(),
        markdownRenderer: MarkdownRenderer = MarkdownRenderer(),
        fileWatcher: FileWatcher = FileWatcher()
    ) {
        self.preferencesStore = preferencesStore
        self.documentAccessController = documentAccessController
        self.markdownRenderer = markdownRenderer
        self.fileWatcher = fileWatcher
        self.recentFiles = preferencesStore.loadRecentFiles()
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
        restoreWindowFrameIfPossible()

        if let path = ProcessInfo.processInfo.environment["OPENNOW_TEST_FILE"], path.isEmpty == false {
            openDocument(at: URL(fileURLWithPath: path))
            return
        }

        restoreLastDocumentIfNeeded()
    }

    func openDocumentFromPanel() {
        guard let descriptor = documentAccessController.openPanelPickDocument() else {
            return
        }

        open(
            descriptor: descriptor,
            updateRecentFiles: true,
            persistLastOpen: true
        )
    }

    func openDocument(at url: URL) {
        open(
            descriptor: documentAccessController.prepareAccess(for: url),
            updateRecentFiles: true,
            persistLastOpen: true
        )
    }

    func openRecent(_ entry: RecentFileEntry) {
        guard let descriptor = documentAccessController.resolveRecentFile(entry) else {
            loadErrorMessage = "Could not reopen \(entry.displayName)."
            return
        }

        open(
            descriptor: descriptor,
            updateRecentFiles: true,
            persistLastOpen: true
        )
    }

    func restoreLastDocumentIfNeeded() {
        guard let record = preferencesStore.loadLastOpen(),
              let descriptor = documentAccessController.resolveLastOpen(record)
        else {
            return
        }

        open(
            descriptor: descriptor,
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

    func jump(to item: OutlineItem) {
        selectedAnchor = item.anchor
        webBridge.jump(to: item.anchor)
    }

    func clearRecentFiles() {
        preferencesStore.clearRecentFiles()
        recentFiles = []
    }

    func updateWindowFrame(_ frame: CGRect) {
        preferencesStore.saveWindowFrame(frame)
    }

    private func open(
        descriptor: DocumentAccessDescriptor,
        updateRecentFiles: Bool,
        persistLastOpen: Bool,
        preserveScrollPosition: Bool = false
    ) {
        cancelPendingLoad()
        isLoadingDocument = true
        loadErrorMessage = nil
        noticeMessage = nil
        selectedAnchor = nil

        currentAccessSession?.stop()
        currentAccessSession = documentAccessController.startAccess(for: descriptor)
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
                self.noticeMessage = self.notice(for: loadedDocument, descriptor: descriptor)
                self.webBridge.load(
                    html: loadedDocument.renderedHTML,
                    baseURL: loadedDocument.directoryURL,
                    preserveScrollPosition: preserveScrollPosition
                )

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
                self.loadErrorMessage = "Failed to open \(descriptor.fileURL.lastPathComponent): \(error.localizedDescription)"
                self.fileWatcher.stop()
            }
        }
    }

    private func loadDocument(using descriptor: DocumentAccessDescriptor) async throws -> OpenedDocument {
        try await Task.detached(priority: .userInitiated) { [markdownRenderer] in
            let resourceValues = try descriptor.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let markdown = try String(contentsOf: descriptor.fileURL, encoding: .utf8)
            let rendered = try markdownRenderer.render(markdown: markdown, baseURL: descriptor.directoryURL)

            return OpenedDocument(
                url: descriptor.fileURL,
                directoryURL: descriptor.directoryURL,
                bookmarkData: descriptor.directoryBookmarkData ?? descriptor.fileBookmarkData,
                rawMarkdown: markdown,
                renderedHTML: rendered.html,
                outlineItems: rendered.outlineItems,
                lastKnownModificationDate: resourceValues.contentModificationDate,
                containsRelativeImages: rendered.containsRelativeImages
            )
        }.value
    }

    private func attachFileWatcher(for descriptor: DocumentAccessDescriptor) {
        fileWatcher.start(url: descriptor.fileURL) { [weak self] in
            Task { @MainActor in
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
            updateRecentFiles: false,
            persistLastOpen: false,
            preserveScrollPosition: true
        )
    }

    private func restoreWindowFrameIfPossible() {
        guard let frame = preferencesStore.loadWindowFrame(),
              let window = NSApplication.shared.windows.first
        else {
            return
        }

        window.setFrame(frame, display: true)
    }

    private func notice(for document: OpenedDocument, descriptor: DocumentAccessDescriptor) -> String? {
        guard document.containsRelativeImages, descriptor.directoryBookmarkData == nil else {
            return nil
        }

        return "This document uses relative images. If anything is missing, reopen it with File > Open… so OpenNow can access the parent folder."
    }
}
