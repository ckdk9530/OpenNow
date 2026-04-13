import SwiftUI

struct ContentView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        NavigationSplitView {
            SidebarView(coordinator: coordinator)
        } detail: {
            ReaderDetailView(coordinator: coordinator)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        .navigationSplitViewStyle(.balanced)
        .accessibilityIdentifier("root-split-view")
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
                windowDidAttach: coordinator.configureWindow,
                frameDidChange: coordinator.updateWindowFrame(window:frame:)
            )
        )
    }
}

#Preview {
    ContentView(coordinator: AppLaunchCoordinator())
}
