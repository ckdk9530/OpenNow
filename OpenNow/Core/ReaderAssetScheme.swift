import Foundation
import OSLog
import UniformTypeIdentifiers
import WebKit

enum ReaderAssetURLScheme {
    nonisolated static let name = "opennow-file"
    nonisolated private static let legacyHost = "local"

    nonisolated static func makeURL(for fileURL: URL) -> URL {
        let encodedPath = fileURL.standardizedFileURL.path
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? fileURL.standardizedFileURL.path

        var components = URLComponents()
        components.scheme = name
        components.host = ""
        components.percentEncodedPath = encodedPath
        return components.url!
    }

    nonisolated static func resolve(_ url: URL) -> URL? {
        guard url.scheme == name else {
            return nil
        }

        let rawPath: String
        if url.host == legacyHost, url.path.isEmpty == false {
            rawPath = url.path
        } else {
            rawPath = url.path
        }

        let decodedPath = rawPath.removingPercentEncoding ?? rawPath
        guard decodedPath.isEmpty == false else {
            return nil
        }

        return URL(fileURLWithPath: decodedPath).standardizedFileURL
    }
}

final class ReaderAssetSecurityScopeStore {
    static let shared = ReaderAssetSecurityScopeStore()

    private let lock = NSLock()
    private var authorizedDirectories: [URL] = []

    private init() {}

    func replaceAuthorizedDirectories(_ urls: [URL]) {
        lock.lock()
        defer { lock.unlock() }
        authorizedDirectories = Array(Set(urls.map(\.standardizedFileURL))).sorted { $0.path.count > $1.path.count }
    }

    func clear() {
        lock.lock()
        authorizedDirectories = []
        lock.unlock()
    }

    func beginAccess(for fileURL: URL) -> URL? {
        let standardizedFileURL = fileURL.standardizedFileURL

        lock.lock()
        let matchingScope = authorizedDirectories.first { scopeURL in
            standardizedFileURL.pathComponents.starts(with: scopeURL.pathComponents)
        }
        lock.unlock()

        guard let matchingScope else {
            return nil
        }

        return matchingScope.startAccessingSecurityScopedResource() ? matchingScope : nil
    }

    func endAccess(for scopeURL: URL) {
        scopeURL.stopAccessingSecurityScopedResource()
    }
}

final class ReaderAssetSchemeHandler: NSObject, WKURLSchemeHandler {
    private let logger = Logger(subsystem: "com.dahengchen.OpenNow", category: "ReaderAsset")

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = ReaderAssetURLScheme.resolve(requestURL)
        else {
            logger.error("Rejected malformed asset request: \(String(describing: urlSchemeTask.request.url), privacy: .public)")
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        do {
            let activeScopeURL = ReaderAssetSecurityScopeStore.shared.beginAccess(for: fileURL)
            defer {
                if let activeScopeURL {
                    ReaderAssetSecurityScopeStore.shared.endAccess(for: activeScopeURL)
                }
            }

            let data = try Data(contentsOf: fileURL)
            let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            logger.debug("Serving asset \(requestURL.absoluteString, privacy: .public) -> \(fileURL.path, privacy: .public) [\(mimeType, privacy: .public)]")
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            logger.error("Failed to serve asset \(requestURL.absoluteString, privacy: .public) -> \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
