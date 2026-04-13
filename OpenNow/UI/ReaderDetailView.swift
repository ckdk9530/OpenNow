import SwiftUI

struct ReaderDetailView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        Group {
            if let document = coordinator.activeDocument {
                VStack(spacing: 0) {
                    DocumentHeaderView(
                        fileName: document.url.lastPathComponent,
                        parentPath: document.directoryURL.path
                    )

                    Divider()

                    ReaderWebView(
                        html: document.renderedHTML,
                        baseURL: document.directoryURL,
                        bridge: coordinator.webBridge
                    )
                }
                .overlay(alignment: .top) {
                    if let noticeMessage = coordinator.noticeMessage {
                        NoticeBanner(message: noticeMessage)
                            .padding(.top, 12)
                    }
                }
            } else if coordinator.isLoadingDocument {
                LoadingDocumentView()
            } else if let loadErrorMessage = coordinator.loadErrorMessage {
                ContentUnavailableView(
                    "Couldn’t Open Document",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorMessage)
                )
                .accessibilityIdentifier("document-error-state")
            } else {
                EmptyReaderView(
                    recentFiles: coordinator.recentFiles,
                    openRecent: coordinator.openRecent(_:),
                    openPanel: coordinator.openDocumentFromPanel
                )
            }
        }
    }
}

private struct DocumentHeaderView: View {
    let fileName: String
    let parentPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fileName)
                .font(.headline)
                .accessibilityIdentifier("document-name-label")
            Text(parentPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}

private struct NoticeBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct LoadingDocumentView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Opening Markdown…")
                .font(.headline)
            Text("OpenNow shows the shell first and renders the document in the background.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("document-loading-state")
    }
}

private struct EmptyReaderView: View {
    let recentFiles: [RecentFileEntry]
    let openRecent: (RecentFileEntry) -> Void
    let openPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ContentUnavailableView(
                "Open a Markdown File",
                systemImage: "doc.richtext",
                description: Text("OpenNow is optimized for a fast launch, a native shell, and a clean reading surface.")
            )

            Button(action: openPanel) {
                Label("Open Markdown…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)

            if recentFiles.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Files")
                        .font(.headline)

                    ForEach(recentFiles) { entry in
                        Button {
                            openRecent(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                Text(entry.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
