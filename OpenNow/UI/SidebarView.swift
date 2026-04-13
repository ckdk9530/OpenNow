import SwiftUI

struct SidebarView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        ZStack {
            if coordinator.sidebarOutlineItems.isEmpty {
                SidebarEmptyStateView()
            } else {
                List {
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
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
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
                .padding(.leading, CGFloat(max(0, item.level - 1) * 8))
        }
        .contentShape(Rectangle())
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
        VStack(spacing: 0) {
            Divider()

            HStack {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebar-settings-button")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}
