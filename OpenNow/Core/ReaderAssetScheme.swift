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

    typealias AuthorizationHandler = @MainActor (URL) -> URL?

    private let lock = NSLock()
    private var activeSupportDirectories: [URL] = []
    private var authorizationHandler: AuthorizationHandler?

    private init() {}

    func replaceAuthorizedDirectories(_ urls: [URL]) {
        lock.lock()
        defer { lock.unlock() }
        activeSupportDirectories = Array(Set(urls.map(\.standardizedFileURL))).sorted { $0.path.count > $1.path.count }
    }

    func clear() {
        lock.lock()
        activeSupportDirectories = []
        lock.unlock()
    }

    func setAuthorizationHandler(_ handler: AuthorizationHandler?) {
        lock.lock()
        authorizationHandler = handler
        lock.unlock()
    }

    func beginAccess(for fileURL: URL) -> URL? {
        let standardizedFileURL = fileURL.standardizedFileURL

        lock.lock()
        let matchingScope = activeSupportDirectories.first { scopeURL in
            standardizedFileURL.pathComponents.starts(with: scopeURL.pathComponents)
        }
        lock.unlock()

        guard let matchingScope else {
            return nil
        }

        return matchingScope.startAccessingSecurityScopedResource() ? matchingScope : nil
    }

    func requestAuthorization(for fileURL: URL) -> URL? {
        let handler = withLock { authorizationHandler }
        guard let handler else {
            return nil
        }

        let grantedRootURL: URL?
        if Thread.isMainThread {
            grantedRootURL = handler(fileURL.standardizedFileURL)
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            var resolvedRootURL: URL?
            DispatchQueue.main.async {
                resolvedRootURL = handler(fileURL.standardizedFileURL)
                semaphore.signal()
            }
            semaphore.wait()
            grantedRootURL = resolvedRootURL
        }

        guard let grantedRootURL else {
            return nil
        }

        appendAuthorizedDirectory(grantedRootURL)
        return grantedRootURL
    }

    func endAccess(for scopeURL: URL) {
        scopeURL.stopAccessingSecurityScopedResource()
    }

    private func appendAuthorizedDirectory(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }

        let normalizedURL = url.standardizedFileURL
        activeSupportDirectories.removeAll(where: { $0 == normalizedURL })
        activeSupportDirectories.append(normalizedURL)
        activeSupportDirectories.sort { $0.path.count > $1.path.count }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
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
            var activeScopeURL = ReaderAssetSecurityScopeStore.shared.beginAccess(for: fileURL)
            defer {
                if let activeScopeURL {
                    ReaderAssetSecurityScopeStore.shared.endAccess(for: activeScopeURL)
                }
            }

            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                guard Self.isPermissionDenied(error),
                      let authorizedRootURL = ReaderAssetSecurityScopeStore.shared.requestAuthorization(for: fileURL),
                      authorizedRootURL.startAccessingSecurityScopedResource()
                else {
                    throw error
                }

                activeScopeURL = authorizedRootURL
                data = try Data(contentsOf: fileURL)
            }
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

    private static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoPermissionError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == EACCES || nsError.code == EPERM {
            return true
        }

        return false
    }
}
