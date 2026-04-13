import SwiftUI

struct ContentView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        NavigationSplitView {
            SidebarView(coordinator: coordinator)
        } detail: {
            ReaderDetailView(coordinator: coordinator)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .accessibilityIdentifier("root-split-view")
        .toolbar {
            ToolbarItemGroup {
                Button(action: coordinator.openDocumentFromPanel) {
                    Label("Open", systemImage: "folder")
                }

                if coordinator.isLoadingDocument {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .background(WindowObserver(frameDidChange: coordinator.updateWindowFrame))
    }
}

#Preview {
    ContentView(coordinator: AppLaunchCoordinator())
}
