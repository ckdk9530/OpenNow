import SwiftUI

struct ContentView: View {
    @Bindable var coordinator: AppLaunchCoordinator
    let windowChromeController: any WindowChromeControlling

    var body: some View {
        NavigationSplitView {
            SidebarView(coordinator: coordinator)
        } detail: {
            ReaderDetailView(coordinator: coordinator)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        .navigationSplitViewStyle(.prominentDetail)
        .accessibilityIdentifier("root-split-view")
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Button(action: coordinator.openDocumentFromPanel) {
                    Label("Open Markdown", systemImage: "doc")
                }

                if coordinator.isLoadingDocument {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .background(
            WindowObserver(
                windowDidAttach: { window in
                    windowChromeController.attach(window: window)
                },
                frameDidChange: { window, frame in
                    windowChromeController.persistFrame(window: window, frame: frame)
                }
            )
        )
    }
}

#Preview {
    let preferencesStore = PreferencesStore()
    let windowChromeController = DefaultWindowChromeController(preferencesStore: preferencesStore)
    let coordinator = AppLaunchCoordinator(
        preferencesStore: preferencesStore,
        documentAccessController: DocumentAccessController(),
        markdownRenderer: MarkdownRenderer(),
        fileWatcher: FileWatcher(),
        panelPresenter: AppKitDocumentPanelPresenter(),
        alertPresenter: AppKitDocumentAlertPresenter(),
        windowChromeController: windowChromeController
    )

    return ContentView(
        coordinator: coordinator,
        windowChromeController: windowChromeController
    )
}
