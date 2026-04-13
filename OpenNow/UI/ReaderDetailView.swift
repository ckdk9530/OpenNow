import SwiftUI

struct ReaderDetailView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        ZStack {
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
                            documentURL: document.url,
                            baseURL: document.directoryURL,
                            bridge: coordinator.webBridge
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    }
                } else if coordinator.isLoadingDocument {
                    LoadingDocumentView()
                } else if let loadErrorMessage = coordinator.loadErrorMessage {
                    DocumentErrorView(message: loadErrorMessage)
                } else {
                    EmptyReaderView(
                        recentFiles: coordinator.recentFiles,
                        authorizedFolders: coordinator.authorizedFolders,
                        openRecent: coordinator.openRecent(_:),
                        openPanel: coordinator.openDocumentFromPanel
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-detail-pane")
    }
}

private struct DocumentHeaderView: View {
    let fileName: String
    let parentPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fileName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("document-name-label")
                .accessibilityLabel("document-header-title")
            Text(parentPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .accessibilityIdentifier("document-header")
    }
}

private struct LoadingDocumentView: View {
    var body: some View {
        ReaderStateContainer {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                Text("Opening Markdown…")
                    .font(.headline)

                Text("OpenNow shows the shell first and renders the document in the background.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("document-loading-state")
    }
}

private struct DocumentErrorView: View {
    let message: String

    var body: some View {
        ReaderStateContainer {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Couldn’t Open Document")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("document-error-state")
    }
}

private struct EmptyReaderView: View {
    let recentFiles: [RecentFileEntry]
    let authorizedFolders: [AuthorizedFolderEntry]
    let openRecent: (RecentFileEntry) -> Void
    let openPanel: () -> Void

    var body: some View {
        ReaderStateContainer(alignment: hasSupplementarySections ? .leading : .center) {
            VStack(alignment: hasSupplementarySections ? .leading : .center, spacing: 22) {
                VStack(alignment: hasSupplementarySections ? .leading : .center, spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Open a Markdown File")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(hasSupplementarySections ? .leading : .center)
                        .accessibilityIdentifier("empty-reader-title")

                    Text("OpenNow is optimized for a fast launch, a native shell, and a clean reading surface.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(hasSupplementarySections ? .leading : .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("empty-reader-message")
                }

                Button(action: openPanel) {
                    Label("Open Markdown…", systemImage: "doc")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("open-markdown-button")
                .accessibilityLabel("Open Markdown…")

                if authorizedFolders.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Authorized Roots")
                            .font(.headline)

                        ForEach(authorizedFolders.prefix(3)) { entry in
                            Label(entry.path, systemImage: "folder.badge.checkmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("OpenNow requests a durable root folder automatically when a Markdown file needs relative assets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

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
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("empty-reader-state")
    }

    private var hasSupplementarySections: Bool {
        authorizedFolders.isEmpty == false || recentFiles.isEmpty == false
    }
}

private struct ReaderStateContainer<Content: View>: View {
    let alignment: Alignment
    @ViewBuilder let content: () -> Content

    init(alignment: Alignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = idealContentWidth(for: proxy.size.width)
            let horizontalPadding = min(max(proxy.size.width * 0.045, 20), 40)

            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .frame(maxWidth: contentWidth, alignment: alignment)
                    .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 32, 0), alignment: alignment)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func idealContentWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth - 56, 280), 620)
    }
}
