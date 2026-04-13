import AppKit
import SwiftUI
import WebKit

struct ReaderWebView: NSViewControllerRepresentable {
    let html: String
    let documentURL: URL
    let baseURL: URL
    let bridge: ReaderWebBridge

    func makeNSViewController(context: Context) -> ReaderWebViewController {
        ReaderWebViewController(bridge: bridge)
    }

    func updateNSViewController(_ controller: ReaderWebViewController, context: Context) {
        controller.render(html: html, documentURL: documentURL, baseURL: baseURL)
    }
}

final class ReaderWebViewController: NSViewController {
    private let bridge: ReaderWebBridge
    private let assetSchemeHandler: ReaderAssetSchemeHandler
    private let webView: WKWebView

    init(bridge: ReaderWebBridge) {
        self.bridge = bridge
        let assetSchemeHandler = ReaderAssetSchemeHandler()
        self.assetSchemeHandler = assetSchemeHandler

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setURLSchemeHandler(assetSchemeHandler, forURLScheme: ReaderAssetURLScheme.name)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setAccessibilityIdentifier("reader-web-view")
        self.webView = webView

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let containerView = AppearanceAwareView()
        containerView.onAppearanceChange = { [weak self] in
            self?.updateColorScheme()
        }
        webView.frame = containerView.bounds
        webView.autoresizingMask = [.width, .height]
        containerView.addSubview(webView)

        self.view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.attach(webView)
        updateColorScheme()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        webView.frame = view.bounds
    }

    func render(html: String, documentURL: URL, baseURL: URL) {
        bridge.attach(webView)
        bridge.load(
            html: html,
            baseURL: baseURL,
            documentURL: documentURL,
            preserveScrollPosition: true
        )
    }

    private func updateColorScheme() {
        let isDark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        bridge.setColorScheme(isDark: isDark)
    }
}

private final class AppearanceAwareView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}
