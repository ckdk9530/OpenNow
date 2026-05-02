import SwiftUI

@main
struct OpenNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let preferencesStore: PreferencesStore
    @State private var coordinator: AppLaunchCoordinator
    @State private var windowChromeController: DefaultWindowChromeController

    init() {
        let preferencesStore = PreferencesStore()
        self.preferencesStore = preferencesStore
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

        _windowChromeController = State(initialValue: windowChromeController)
        _coordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        Window("OpenNow", id: "main") {
            ContentView(
                coordinator: coordinator,
                preferencesStore: preferencesStore,
                windowChromeController: windowChromeController
            )
                .task {
                    RuntimeEnvironment.writeLaunchDiagnostics()
                    let pendingLaunchURLs = appDelegate.drainPendingURLs()
                    appDelegate.openHandler = { urls in
                        for url in urls {
                            coordinator.openDocument(at: url)
                        }
                    }
                    coordinator.start()

                    for url in pendingLaunchURLs {
                        coordinator.openLaunchDocument(at: url)
                    }
                }
        }
        .defaultSize(width: 1040, height: 660)
        .commands {
            OpenNowCommands(coordinator: coordinator)
        }

        Settings {
            SettingsView()
        }
    }
}
