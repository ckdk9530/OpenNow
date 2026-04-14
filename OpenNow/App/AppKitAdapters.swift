import AppKit
import Foundation

@MainActor
protocol DocumentPanelPresenting {
    func pickDocumentURL(startingDirectory: URL?) -> URL?
}

enum LoadFailureAlertAction {
    case dismiss
    case openMarkdownPanel
}

enum SupportingFilesRecoveryChoice {
    case selectedFolder(URL)
    case continueWithoutImages
    case unavailable
}

@MainActor
protocol DocumentAlertPresenting {
    func recoverSupportingFilesAccess(
        for documentURL: URL,
        suggestedDirectory: URL?,
        unresolvedAssetURLs: [URL]
    ) -> SupportingFilesRecoveryChoice
    func retrySupportingFilesSelection(
        selectedDirectory: URL,
        suggestedDirectory: URL,
        unresolvedAssetURLs: [URL]
    ) -> Bool
    func presentLoadFailure(
        message: String,
        allowsOpenMarkdownPanel: Bool
    ) -> LoadFailureAlertAction
}

@MainActor
protocol WindowChromeControlling {
    func attach(window: NSWindow)
    func persistFrame(window: NSWindow, frame: CGRect)
    func apply(document: OpenedDocument?)
}

@MainActor
final class AppKitDocumentPanelPresenter: DocumentPanelPresenting {
    func pickDocumentURL(startingDirectory: URL?) -> URL? {
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
}

@MainActor
final class AppKitDocumentAlertPresenter: DocumentAlertPresenting {
    func recoverSupportingFilesAccess(
        for documentURL: URL,
        suggestedDirectory: URL?,
        unresolvedAssetURLs: [URL]
    ) -> SupportingFilesRecoveryChoice {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Access to Supporting Files"
        alert.informativeText = recoveryMessage(
            documentURL: documentURL,
            unresolvedAssetURLs: unresolvedAssetURLs
        )
        alert.addButton(withTitle: "Choose Folder…")
        alert.addButton(withTitle: "Continue Without Images")

        guard run(alert: alert) == .alertFirstButtonReturn else {
            return .continueWithoutImages
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.directoryURL = suggestedDirectory
        panel.message = "Choose the folder that contains this document’s supporting files."
        panel.prompt = "Choose Folder"

        guard run(panel: panel) == .OK, let folderURL = panel.url else {
            return .unavailable
        }

        return .selectedFolder(folderURL)
    }

    func retrySupportingFilesSelection(
        selectedDirectory: URL,
        suggestedDirectory: URL,
        unresolvedAssetURLs: [URL]
    ) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Choose a Folder That Covers the Supporting Files"
        alert.informativeText = "\(selectedDirectory.path) does not cover every missing supporting file. Choose \(suggestedDirectory.path) or one of its parent folders instead."
        alert.addButton(withTitle: "Choose Again")
        alert.addButton(withTitle: "Cancel")

        return run(alert: alert) == .alertFirstButtonReturn
    }

    func presentLoadFailure(
        message: String,
        allowsOpenMarkdownPanel: Bool
    ) -> LoadFailureAlertAction {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t Open Document"
        alert.informativeText = message

        if allowsOpenMarkdownPanel {
            alert.addButton(withTitle: "Open Markdown…")
            alert.addButton(withTitle: "OK")
            return run(alert: alert) == .alertFirstButtonReturn ? .openMarkdownPanel : .dismiss
        }

        alert.addButton(withTitle: "OK")
        _ = run(alert: alert)
        return .dismiss
    }

    private func recoveryMessage(documentURL: URL, unresolvedAssetURLs: [URL]) -> String {
        if unresolvedAssetURLs.count <= 1, let assetURL = unresolvedAssetURLs.first {
            return "\(documentURL.lastPathComponent) references a local supporting file outside the current access scope.\n\nMissing file: \(assetURL.lastPathComponent)"
        }

        return "\(documentURL.lastPathComponent) references local supporting files outside the current access scope.\n\nChoose a folder that covers the missing images or related files so the document can finish rendering."
    }

    private func run(alert: NSAlert) -> NSApplication.ModalResponse {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            return runSheet(for: window) { completion in
                alert.beginSheetModal(for: window, completionHandler: completion)
            }
        }

        return alert.runModal()
    }

    private func run(panel: NSOpenPanel) -> NSApplication.ModalResponse {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            return runSheet(for: window) { completion in
                panel.beginSheetModal(for: window, completionHandler: completion)
            }
        }

        return panel.runModal()
    }

    private func runSheet(
        for window: NSWindow,
        begin: (@escaping (NSApplication.ModalResponse) -> Void) -> Void
    ) -> NSApplication.ModalResponse {
        var response: NSApplication.ModalResponse = .cancel
        begin { modalResponse in
            response = modalResponse
            NSApp.stopModal()
        }
        NSApp.runModal(for: window)
        return response
    }
}

@MainActor
final class DefaultWindowChromeController: WindowChromeControlling {
    private let preferencesStore: PreferencesStore
    private weak var attachedWindow: NSWindow?
    private var hasRestoredWindowFrame = false

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
    }

    func attach(window: NSWindow) {
        attachedWindow = window
        window.minSize = NSSize(width: 620, height: 420)

        preferencesStore.clearSystemWindowAutosaveArtifacts()
        restoreWindowFrameIfPossible(using: window)
    }

    func persistFrame(window: NSWindow, frame: CGRect) {
        guard shouldPersistWindowFrame(window: window) else {
            return
        }

        preferencesStore.saveWindowFrame(frame)
    }

    func apply(document: OpenedDocument?) {
        guard let window = attachedWindow else {
            return
        }

        if let document {
            window.title = document.url.lastPathComponent
            window.subtitle = document.directoryURL.path
            window.representedURL = document.url
        } else {
            window.title = "OpenNow"
            window.subtitle = ""
            window.representedURL = nil
        }
    }

    private func restoreWindowFrameIfPossible(using window: NSWindow) {
        guard hasRestoredWindowFrame == false,
              let frame = preferencesStore.loadWindowFrame()
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
}
