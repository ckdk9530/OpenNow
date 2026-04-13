import SwiftUI

struct OpenNowCommands: Commands {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
        }

        CommandGroup(after: .newItem) {
            Button("Open…", action: coordinator.openDocumentFromPanel)
                .keyboardShortcut("o", modifiers: [.command])

            Divider()

            if coordinator.recentFiles.isEmpty {
                Button("No Recent Files") {
                }
                .disabled(true)
            } else {
                Menu("Open Recent") {
                    ForEach(coordinator.recentFiles) { entry in
                        Button(entry.displayName) {
                            coordinator.openRecent(entry)
                        }
                    }

                    Divider()

                    Button("Clear Menu") {
                        coordinator.clearRecentFiles()
                    }
                }
            }
        }

        CommandMenu("Reader") {
            Button("Page Down") {
                coordinator.page(.down)
            }
            .keyboardShortcut(KeyEquivalent(" "), modifiers: [])
            .disabled(coordinator.activeDocument == nil)

            Button("Page Up") {
                coordinator.page(.up)
            }
            .keyboardShortcut(KeyEquivalent(" "), modifiers: [.shift])
            .disabled(coordinator.activeDocument == nil)
        }
    }
}
