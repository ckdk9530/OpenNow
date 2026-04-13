import SwiftUI

struct SidebarView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if coordinator.sidebarOutlineItems.isEmpty {
                SidebarEmptyStateView()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(coordinator.sidebarOutlineItems) { item in
                            Button {
                                coordinator.jump(to: item)
                            } label: {
                                OutlineRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("outline-item-\(item.anchor)")
                            .accessibilityLabel(item.title)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar-pane")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooterView()
        }
    }
}

private struct OutlineRow: View {
    let item: OutlineItem

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 4, height: 14)
                .opacity(max(0, 0.4 - Double(item.level) * 0.08))

            Text(item.title)
                .font(item.level == 1 ? .headline : .body)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.leading, CGFloat(max(0, item.level - 1) * 8))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SidebarEmptyStateView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "list.bullet.indent")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("No Outline Yet")
                    .font(.headline.weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sidebar-empty-title")

                Text("Open a Markdown file to populate the sidebar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sidebar-empty-message")
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 64)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar-empty-state")
    }
}

private struct SidebarFooterView: View {
    var body: some View {
        HStack {
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("sidebar-settings-button")

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
