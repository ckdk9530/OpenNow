import AppKit
import Foundation

@MainActor
protocol DocumentPanelPresenting {
    func pickDocumentURL(startingDirectory: URL?) -> URL?
    func pickFolderURL(
        suggestedDirectory: URL?,
        message: String,
        prompt: String
    ) -> URL?
}

enum LoadFailureAlertAction {
    case dismiss
    case openMarkdownPanel
}

@MainActor
protocol DocumentAlertPresenting {
    func confirmFolderTreeAccess(for fileURL: URL, preferredRootURL: URL) -> Bool
    func retryFolderTreeAccessSelection(
        selectedRootURL: URL,
        preferredRootURL: URL,
        fileURL: URL
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

    func pickFolderURL(
        suggestedDirectory: URL?,
        message: String,
        prompt: String
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.directoryURL = suggestedDirectory
        panel.message = message
        panel.prompt = prompt

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}

@MainActor
final class AppKitDocumentAlertPresenter: DocumentAlertPresenting {
    func confirmFolderTreeAccess(for fileURL: URL, preferredRootURL: URL) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Authorize a Folder Tree?"
        alert.informativeText = "This Markdown file references relative assets. OpenNow needs a durable root-folder bookmark so sibling images and future files in the same tree keep working. Suggested root: \(preferredRootURL.path)"
        alert.addButton(withTitle: "Authorize Root…")
        alert.addButton(withTitle: "Open File Only")

        return alert.runModal() == .alertFirstButtonReturn
    }

    func retryFolderTreeAccessSelection(
        selectedRootURL: URL,
        preferredRootURL: URL,
        fileURL: URL
    ) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Choose the suggested root or one of its parent folders."
        alert.informativeText = "\(fileURL.lastPathComponent) should be authorized from \(preferredRootURL.path), not from a narrower child folder (\(selectedRootURL.path))."
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
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
            return alert.runModal() == .alertFirstButtonReturn ? .openMarkdownPanel : .dismiss
        }

        alert.addButton(withTitle: "OK")
        alert.runModal()
        return .dismiss
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
