import SwiftUI

struct SettingsView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        TabView {
            AccessSettingsView(coordinator: coordinator)
                .tabItem {
                    Label("Access", systemImage: "folder.badge.gearshape")
                }
        }
        .frame(minWidth: 620, minHeight: 440)
    }
}

private struct AccessSettingsView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Access")
                    .font(.title2.weight(.semibold))

                Text("OpenNow is designed to work with folder-based access. Full Disk Access is optional and managed by macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: fullDiskAccessIconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(fullDiskAccessTint)
                            .frame(width: 26)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(fullDiskAccessTitle)
                                .font(.headline)

                            Text(fullDiskAccessMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Open Full Disk Access") {
                            coordinator.openFullDiskAccessSettings()
                        }
                        .buttonStyle(.bordered)

                        Button("Refresh Status") {
                            coordinator.refreshFullDiskAccessStatus()
                        }
                        .buttonStyle(.bordered)

                        Button("Open System Settings") {
                            coordinator.openSystemSettings()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    Text("Status detection is best-effort only. OpenNow still treats folder-tree bookmarks as the primary access path, and Full Disk Access remains an advanced macOS-level override.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Full Disk Access")
            }

            HStack(spacing: 10) {
                Button("Add Folder Access…") {
                    coordinator.addAuthorizedFolderFromPanel()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }

            GroupBox {
                if coordinator.authorizedFolders.isEmpty {
                    ContentUnavailableView(
                        "No Authorized Folder Roots",
                        systemImage: "folder",
                        description: Text("Add a folder root such as Desktop, Documents, or a notes workspace to reuse access across that tree.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    List {
                        ForEach(coordinator.authorizedFolders) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.displayName)
                                        .font(.headline)
                                    Text(entry.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }

                                Spacer()

                                Text(entry.lastUsedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Remove Access") {
                                    coordinator.removeAuthorizedFolder(entry)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 260)
                }
            } label: {
                HStack {
                    Text("Authorized Folder Roots")
                    Spacer()
                    Text("\(coordinator.authorizedFolders.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Removing an authorized root stops OpenNow from reusing that bookmark in future opens. The currently open document may keep working until you close or reload it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(24)
        .task {
            coordinator.refreshFullDiskAccessStatusIfNeeded()
        }
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
}

#Preview {
    SettingsView(coordinator: AppLaunchCoordinator())
}
