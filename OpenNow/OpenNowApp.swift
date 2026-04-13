import SwiftUI

@main
struct OpenNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppLaunchCoordinator()

    var body: some Scene {
        Window("OpenNow", id: "main") {
            ContentView(coordinator: coordinator)
                .task {
                    RuntimeEnvironment.writeLaunchDiagnostics()
                    let pendingLaunchURLs = appDelegate.drainPendingURLs()
                    appDelegate.openHandler = { urls in
                        for url in urls {
                            coordinator.openDocument(at: url)
                        }
                    }
                    coordinator.start(skipRestore: pendingLaunchURLs.isEmpty == false)

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
