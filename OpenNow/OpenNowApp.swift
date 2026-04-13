import SwiftUI

@main
struct OpenNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppLaunchCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .task {
                    appDelegate.openHandler = { urls in
                        for url in urls {
                            coordinator.openDocument(at: url)
                        }
                    }
                    appDelegate.flushPendingURLsIfNeeded()
                    coordinator.start()
                }
        }
        .commands {
            OpenNowCommands(coordinator: coordinator)
        }
    }
}
