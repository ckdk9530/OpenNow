import SwiftUI

struct SettingsView: View {
    @State private var markdownDefaultsController = MarkdownDefaultAppController()
    @State private var donationStore = DonationStore()

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

            Section {
                ForEach(donationStore.featuredTiers) { tier in
                    DonationTierRow(
                        tier: tier,
                        priceLabel: donationStore.displayPrice(for: tier),
                        isBusy: donationStore.isPurchasing(tier)
                    ) {
                        Task {
                            await donationStore.purchase(tier)
                        }
                    }
                }
            } footer: {
                Text("Optional one-time support purchases through the App Store. OpenNow stays fully usable without purchase.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 540, minHeight: 360)
        .task {
            markdownDefaultsController.refreshStatus()
            await donationStore.loadProductsIfNeeded()
        }
        .alert(activeBannerTitle, isPresented: bannerIsPresented) {
            Button("OK") {
                clearBanners()
            }
        } message: {
            Text(activeBannerMessage)
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
            get: { donationStore.banner != nil || markdownDefaultsController.banner != nil },
            set: { isPresented in
                if isPresented == false {
                    clearBanners()
                }
            }
        )
    }

    private var activeBannerTitle: String {
        markdownDefaultsController.banner?.title ?? donationStore.banner?.title ?? ""
    }

    private var activeBannerMessage: String {
        markdownDefaultsController.banner?.message ?? donationStore.banner?.message ?? ""
    }

    private func clearBanners() {
        markdownDefaultsController.clearBanner()
        donationStore.clearBanner()
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

private struct DonationTierRow: View {
    let tier: DonationStore.DonationTier
    let priceLabel: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.title)
                    .font(.body.weight(.medium))

                Text(tier.caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Text(priceLabel)
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 54, alignment: .trailing)

            Button(isBusy ? "Processing…" : "Buy") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isBusy)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
}
