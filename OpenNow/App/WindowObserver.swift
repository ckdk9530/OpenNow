import AppKit
import SwiftUI

struct WindowObserver: NSViewRepresentable {
    let frameDidChange: (CGRect) -> Void

    func makeNSView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        view.frameDidChange = frameDidChange
        return view
    }

    func updateNSView(_ nsView: WindowObserverView, context: Context) {
        nsView.frameDidChange = frameDidChange
    }
}

final class WindowObserverView: NSView {
    var frameDidChange: ((CGRect) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var hasEmittedInitialFrame = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func attachIfNeeded() {
        guard let window else {
            return
        }

        if observers.isEmpty {
            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSWindow.didMoveNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.emitFrame()
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSWindow.didEndLiveResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.emitFrame()
                }
            )
        }

        if hasEmittedInitialFrame == false {
            hasEmittedInitialFrame = true
            emitFrame()
        }
    }

    private func emitFrame() {
        guard let window else {
            return
        }

        frameDidChange?(window.frame)
    }
}
