import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        AccessSettingsView(coordinator: coordinator)
            .frame(minWidth: 620, minHeight: 440)
    }
}

private struct AccessSettingsView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Label(fullDiskAccessTitle, systemImage: fullDiskAccessIconName)
                        .foregroundStyle(fullDiskAccessTint)
                }

                LabeledContent(primaryFullDiskAccessActionTitle) {
                    Button(primaryFullDiskAccessButtonTitle) {
                        coordinator.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.bordered)
                }

                LabeledContent("Check Again") {
                    Button("Refresh") {
                        coordinator.refreshFullDiskAccessStatus()
                    }
                    .buttonStyle(.link)
                }
            } header: {
                Text("Full Disk Access")
            } footer: {
                Text("\(fullDiskAccessMessage) Status detection is best-effort only. Folder-tree bookmarks remain the primary access path.")
            }

            Section {
                LabeledContent("Authorized Roots") {
                    Text(folderCountLabel)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Add Folder Access…") {
                        coordinator.addAuthorizedFolderFromPanel()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            } header: {
                Text("Authorized Folder Roots")
            } footer: {
                Text("OpenNow works best when you grant access at the folder level. Removing an authorized root stops OpenNow from reusing that bookmark in future opens, although the current document may keep working until you close or reload it.")
            }

            if coordinator.authorizedFolders.isEmpty {
                Section {
                    Text("No authorized folder roots. Add a folder such as Desktop, Documents, or a notes workspace to reuse access across that tree.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Section {
                    ForEach(coordinator.authorizedFolders) { entry in
                        AuthorizedFolderRow(entry: entry) {
                            coordinator.removeAuthorizedFolder(entry)
                        }
                    }
                } header: {
                    Text("Authorized Folders")
                }
            }
        }
        .formStyle(.grouped)
        .task {
            coordinator.refreshFullDiskAccessStatusIfNeeded()
        }
    }

    private var folderCountLabel: String {
        "\(coordinator.authorizedFolders.count)"
    }

    private var fullDiskAccessTitle: String {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            "Full Disk Access Looks Enabled"
        case .notDetected:
            "Full Disk Access Not Detected"
        case .indeterminate:
            "Full Disk Access Couldn’t Be Verified"
        }
    }

    private var fullDiskAccessMessage: String {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            "OpenNow could read at least one macOS-protected location that normally requires extra privacy approval. This looks like Full Disk Access is enabled for the current app build."
        case .notDetected:
            "OpenNow could not read macOS-protected locations that usually open up only with Full Disk Access. Folder-tree authorization is still the supported default."
        case .indeterminate:
            "OpenNow could not verify the current macOS privacy state on this machine. If you need broad access beyond folder bookmarks, use the button below to jump straight to Full Disk Access."
        }
    }

    private var fullDiskAccessIconName: String {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            "checkmark.shield"
        case .notDetected:
            "lock.shield"
        case .indeterminate:
            "questionmark.shield"
        }
    }

    private var fullDiskAccessTint: Color {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            .green
        case .notDetected:
            .orange
        case .indeterminate:
            .secondary
        }
    }

    private var primaryFullDiskAccessActionTitle: String {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            "Manage"
        case .notDetected, .indeterminate:
            "Action"
        }
    }

    private var primaryFullDiskAccessButtonTitle: String {
        switch coordinator.fullDiskAccessStatus {
        case .likelyEnabled:
            "Open in System Settings…"
        case .notDetected, .indeterminate:
            "Open Full Disk Access…"
        }
    }
}

private struct AuthorizedFolderRow: View {
    let entry: AuthorizedFolderEntry
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.body.weight(.medium))

                Text(entry.path)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Last used \(entry.lastUsedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(role: .destructive) {
                remove()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove Access")
            .accessibilityLabel("Remove access for \(entry.displayName)")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView(coordinator: AppLaunchCoordinator())
}
