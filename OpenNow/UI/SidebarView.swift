import SwiftUI

struct SidebarView: View {
    @Bindable var coordinator: AppLaunchCoordinator

    var body: some View {
        List(selection: $coordinator.selectedAnchor) {
            if coordinator.sidebarOutlineItems.isEmpty {
                ContentUnavailableView(
                    "No Outline Yet",
                    systemImage: "list.bullet.indent",
                    description: Text("Open a Markdown file to populate the sidebar.")
                )
                .accessibilityIdentifier("sidebar-empty-state")
            } else {
                ForEach(coordinator.sidebarOutlineItems) { item in
                    Button {
                        coordinator.jump(to: item)
                    } label: {
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
                    }
                    .buttonStyle(.plain)
                    .tag(item.anchor)
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar-pane")
    }
}
