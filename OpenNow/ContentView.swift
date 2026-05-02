import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var coordinator: AppLaunchCoordinator
    @Environment(\.openSettings) private var openSettings
    let preferencesStore: PreferencesStore
    let windowChromeController: any WindowChromeControlling
    @State private var markdownDefaultsController = MarkdownDefaultAppController()
    @State private var showsDefaultViewerOnboarding = false
    @State private var hasEvaluatedOnboarding = false
    @State private var hasOpenedSettingsOnLaunch = false
    private let defaultViewerOnboardingDelay: Duration = .seconds(2)

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
        .task { await presentDefaultViewerOnboardingIfNeeded() }
        .task { await openSettingsOnLaunchIfNeeded() }
        .sheet(isPresented: $showsDefaultViewerOnboarding, onDismiss: completeDefaultViewerOnboarding) {
            DefaultViewerOnboardingView {
                completeDefaultViewerOnboarding()
            }
        }
    }

    private func presentDefaultViewerOnboardingIfNeeded() async {
        guard hasEvaluatedOnboarding == false else {
            return
        }

        hasEvaluatedOnboarding = true

        guard RuntimeEnvironment.suppressesOnboarding() == false else {
            return
        }

        guard preferencesStore.hasCompletedDefaultViewerOnboarding() == false else {
            return
        }

        try? await Task.sleep(for: defaultViewerOnboardingDelay)

        guard coordinator.activeDocument == nil, coordinator.isLoadingDocument == false else {
            return
        }

        markdownDefaultsController.refreshStatus()

        guard markdownDefaultsController.isOpenNowDefault == false else {
            return
        }

        showsDefaultViewerOnboarding = true
    }

    private func completeDefaultViewerOnboarding() {
        guard preferencesStore.hasCompletedDefaultViewerOnboarding() == false else {
            return
        }

        preferencesStore.markDefaultViewerOnboardingCompleted()
    }

    @MainActor
    private func openSettingsOnLaunchIfNeeded() async {
        applyDebugScreenshotAppearanceIfNeeded()

        guard hasOpenedSettingsOnLaunch == false else {
            return
        }

        guard RuntimeEnvironment.opensSettingsOnLaunch() else {
            return
        }

        hasOpenedSettingsOnLaunch = true
        try? await Task.sleep(for: .milliseconds(300))
        openSettings()
    }

    @MainActor
    private func applyDebugScreenshotAppearanceIfNeeded() {
        guard RuntimeEnvironment.forcesDarkAppearance() else {
            return
        }

        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

private struct DefaultViewerOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    let completion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Open Markdown files in OpenNow", systemImage: "doc.text.magnifyingglass")
                .font(.title3.weight(.semibold))

            Text("You can make OpenNow the default viewer for \(MarkdownDefaultAppController.supportedExtensionsDescription) from Settings.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Not Now") {
                    completion()
                    dismiss()
                }

                Button("Open Settings") {
                    completion()
                    dismiss()

                    Task { @MainActor in
                        openSettings()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(width: 420)
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
        preferencesStore: preferencesStore,
        windowChromeController: windowChromeController
    )
}
