import Foundation
import WebKit

@MainActor
final class ReaderWebBridge: NSObject {
    private weak var webView: WKWebView?
    private var pendingScrollFraction: Double?
    private var lastRenderedSignature: String?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
    }

    func load(html: String, baseURL: URL, preserveScrollPosition: Bool) {
        Task {
            if preserveScrollPosition {
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
            webView?.loadHTMLString(html, baseURL: baseURL)
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
}

extension ReaderWebBridge: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let pendingScrollFraction else {
            return
        }

        Task {
            await restoreScrollFraction(pendingScrollFraction)
            self.pendingScrollFraction = nil
        }
    }
}
