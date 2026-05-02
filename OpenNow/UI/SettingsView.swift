import SwiftUI

struct SettingsView: View {
    @State private var markdownDefaultsController = MarkdownDefaultAppController()

    var body: some View {
        Form {
            Section {
                DefaultViewerRow(
                    title: defaultsTitle,
                    status: defaultsStatus,
                    buttonTitle: defaultsButtonTitle,
                    isBusy: markdownDefaultsController.isUpdating,
                    isDefault: markdownDefaultsController.isOpenNowDefault,
                    setAsDefault: {
                        Task {
                            await markdownDefaultsController.setAsDefaultViewer()
                        }
                    },
                    refresh: { markdownDefaultsController.refreshStatus() }
                )
            } header: {
                Text("Markdown Defaults")
            } footer: {
                Text(defaultsDescription)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, minHeight: 240)
        .task {
            markdownDefaultsController.refreshStatus()
        }
        .alert(markdownDefaultsController.banner?.title ?? "", isPresented: bannerIsPresented) {
            Button("OK") {
                markdownDefaultsController.clearBanner()
            }
        } message: {
            Text(markdownDefaultsController.banner?.message ?? "")
        }
    }

    private var defaultsTitle: String {
        "Default Markdown Viewer"
    }

    private var defaultsStatus: String {
        if markdownDefaultsController.isOpenNowDefault {
            return "OpenNow"
        }

        return markdownDefaultsController.currentDefaultDisplayName ?? "Not Set"
    }

    private var defaultsDescription: String {
        if markdownDefaultsController.isOpenNowDefault {
            return "OpenNow is currently the default viewer for \(MarkdownDefaultAppController.supportedExtensionsDescription)."
        }

        if let currentDefaultDisplayName = markdownDefaultsController.currentDefaultDisplayName {
            return "\(currentDefaultDisplayName) is still opening Markdown files. Make OpenNow the default viewer for \(MarkdownDefaultAppController.supportedExtensionsDescription)."
        }

        return "Make OpenNow the default viewer for \(MarkdownDefaultAppController.supportedExtensionsDescription)."
    }

    private var defaultsButtonTitle: String {
        if markdownDefaultsController.isUpdating {
            return "Applying…"
        }

        if markdownDefaultsController.isOpenNowDefault {
            return "OpenNow Is Default"
        }

        return "Set as Default"
    }

    private var bannerIsPresented: Binding<Bool> {
        Binding(
            get: { markdownDefaultsController.banner != nil },
            set: { isPresented in
                if isPresented == false {
                    markdownDefaultsController.clearBanner()
                }
            }
        )
    }
}

private struct DefaultViewerRow: View {
    let title: String
    let status: String
    let buttonTitle: String
    let isBusy: Bool
    let isDefault: Bool
    let setAsDefault: () -> Void
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: "doc.text.magnifyingglass")
                    .font(.body.weight(.medium))

                Spacer(minLength: 16)

                Text(status)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isDefault ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            }

            HStack(spacing: 12) {
                Button(buttonTitle) {
                    setAsDefault()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || isDefault)

                Button("Refresh") {
                    refresh()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
