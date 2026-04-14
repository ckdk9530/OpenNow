import AppKit
import Foundation
import WebKit

@MainActor
final class ReaderWebBridge: NSObject {
    private weak var webView: WKWebView?
    private var pendingScrollFraction: Double?
    private var lastRenderedSignature: String?
    private var lastRenderedDocumentURL: URL?
    private var attachedWebViewID: ObjectIdentifier?
    private var fontScale: Double = 1.0
    private var colorScheme: String = "light"

    func attach(_ webView: WKWebView) {
        let webViewID = ObjectIdentifier(webView)
        if attachedWebViewID != webViewID {
            lastRenderedSignature = nil
            lastRenderedDocumentURL = nil
            pendingScrollFraction = nil
            attachedWebViewID = webViewID
        }

        self.webView = webView
        webView.navigationDelegate = self
    }

    func load(
        html: String,
        baseURL: URL,
        documentURL: URL,
        preserveScrollPosition: Bool
    ) {
        Task {
            guard let webView else {
                return
            }

            if preserveScrollPosition,
               lastRenderedSignature != nil,
               lastRenderedDocumentURL == documentURL
            {
                pendingScrollFraction = await captureScrollFraction()
            } else {
                pendingScrollFraction = nil
            }

            let signature = "\(baseURL.absoluteString)-\(html.hashValue)"
            guard signature != lastRenderedSignature else {
                if let pendingScrollFraction {
                    await restoreScrollFraction(pendingScrollFraction)
                    self.pendingScrollFraction = nil
                }
                return
            }

            lastRenderedSignature = signature
            lastRenderedDocumentURL = documentURL
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func page(_ direction: ReaderPageDirection) {
        let delta = direction == .down ? 1 : -1
        webView?.evaluateJavaScript("window.OpenNowBridge.pageBy(\(delta));")
    }

    func jump(to anchor: String) {
        let escapedAnchor = anchor.replacingOccurrences(of: "'", with: "\\'")
        webView?.evaluateJavaScript("window.OpenNowBridge.scrollToAnchor('\(escapedAnchor)');")
    }

    func reloadPreservingScrollPosition() {
        Task {
            guard let webView else {
                return
            }

            pendingScrollFraction = await captureScrollFraction()
            webView.reload()
        }
    }

    func setFontScale(_ scale: Double) {
        fontScale = min(max(scale, 0.85), 1.8)
        applyFontScale()
    }

    func setColorScheme(isDark: Bool) {
        colorScheme = isDark ? "dark" : "light"
        applyColorScheme()
    }

    private func captureScrollFraction() async -> Double? {
        guard let webView else {
            return nil
        }

        let value = try? await webView.evaluateJavaScript("window.OpenNowBridge.captureScrollFraction();")
        return value as? Double
    }

    private func restoreScrollFraction(_ fraction: Double) async {
        guard let webView else {
            return
        }

        _ = try? await webView.evaluateJavaScript("window.OpenNowBridge.restoreScrollFraction(\(fraction));")
    }

    private func applyFontScale() {
        webView?.evaluateJavaScript("window.OpenNowBridge.setFontScale(\(fontScale));")
    }

    private func applyColorScheme() {
        webView?.evaluateJavaScript("window.OpenNowBridge.setColorScheme('\(colorScheme)');")
    }
}

extension ReaderWebBridge: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url,
              shouldOpenExternally(url)
        else {
            decisionHandler(.allow)
            return
        }

        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyColorScheme()
        applyFontScale()
        guard let pendingScrollFraction else {
            return
        }

        Task {
            await restoreScrollFraction(pendingScrollFraction)
            self.pendingScrollFraction = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}

    private func shouldOpenExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        switch scheme {
        case "http", "https", "mailto":
            return true
        default:
            return false
        }
    }
}
