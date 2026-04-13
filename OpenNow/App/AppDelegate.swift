import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var openHandler: (([URL]) -> Void)?
    private var pendingURLs: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        if let openHandler {
            openHandler(urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func flushPendingURLsIfNeeded() {
        guard let openHandler, pendingURLs.isEmpty == false else {
            return
        }

        let urls = pendingURLs
        pendingURLs.removeAll()
        openHandler(urls)
    }
}
