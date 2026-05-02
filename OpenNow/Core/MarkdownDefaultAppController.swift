import AppKit
import CoreServices
import Foundation
import Observation

@MainActor
@Observable
final class MarkdownDefaultAppController {
    enum Banner: Equatable {
        case success(String)
        case pending(String)
        case error(String)

        var title: String {
            switch self {
            case .success:
                "Default Viewer Updated"
            case .pending:
                "Waiting for macOS"
            case .error:
                "Couldn't Update Default Viewer"
            }
        }

        var message: String {
            switch self {
            case .success(let message), .pending(let message), .error(let message):
                message
            }
        }
    }

    nonisolated static let supportedExtensionsDescription = ".md, .markdown, and .mdown"

    nonisolated private static let supportedContentTypes = [
        "net.daringfireball.markdown",
        "com.dahengchen.opennow.markdown"
    ]
    nonisolated private static let refreshPollInterval: Duration = .milliseconds(250)
    nonisolated private static let refreshTimeout: Duration = .seconds(12)

    private(set) var isOpenNowDefault = false
    private(set) var currentDefaultDisplayName: String?
    private(set) var isUpdating = false
    var banner: Banner?

    func refreshStatus() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            isOpenNowDefault = false
            currentDefaultDisplayName = nil
            return
        }

        let handlers = Self.supportedContentTypes.map { contentType in
            LSCopyDefaultRoleHandlerForContentType(contentType as CFString, .viewer)?
                .takeRetainedValue() as String?
        }

        isOpenNowDefault = handlers.allSatisfy { $0 == bundleIdentifier }
        currentDefaultDisplayName = handlers
            .compactMap { $0 }
            .first(where: { $0 != bundleIdentifier })
            .flatMap(displayName(forBundleIdentifier:))
    }

    func setAsDefaultViewer() async {
        guard isUpdating == false else {
            return
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            banner = .error("OpenNow couldn't resolve its bundle identifier.")
            return
        }

        isUpdating = true
        defer { isUpdating = false }

        let statuses = Self.supportedContentTypes.map { contentType in
            LSSetDefaultRoleHandlerForContentType(
                contentType as CFString,
                .viewer,
                bundleIdentifier as CFString
            )
        }

        guard statuses.allSatisfy({ $0 == noErr }) else {
            banner = .error("macOS rejected the request to make OpenNow the default Markdown viewer.")
            refreshStatus()
            return
        }

        let updated = await waitForDefaultViewerUpdate()

        if updated, isOpenNowDefault {
            banner = .success("OpenNow will now open Markdown files by default.")
        } else {
            banner = .pending("If macOS is asking for confirmation, approve it first. OpenNow will update after the change lands, or you can press Refresh.")
        }
    }

    func clearBanner() {
        banner = nil
    }

    private func displayName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let values = try? applicationURL.resourceValues(forKeys: [.localizedNameKey, .nameKey])
        return values?.localizedName ?? values?.name ?? applicationURL.deletingPathExtension().lastPathComponent
    }

    private func waitForDefaultViewerUpdate() async -> Bool {
        let start = ContinuousClock.now

        while ContinuousClock.now - start < Self.refreshTimeout {
            refreshStatus()

            if isOpenNowDefault {
                return true
            }

            try? await Task.sleep(for: Self.refreshPollInterval)
        }

        refreshStatus()
        return isOpenNowDefault
    }
}
