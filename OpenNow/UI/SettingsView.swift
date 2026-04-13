import SwiftUI

struct SettingsView: View {
    @State private var donationStore = DonationStore()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Support OpenNow", systemImage: "heart")
                        .font(.headline)

                    Text("OpenNow offers simple one-time support purchases through the App Store.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
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
            } header: {
                Text("Support Amount")
            } footer: {
                Text("Support purchases use standard App Store in-app purchases. Amounts are fixed and do not unlock features.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 280)
        .task {
            await donationStore.loadProductsIfNeeded()
        }
        .alert(donationStore.banner?.title ?? "", isPresented: bannerIsPresented) {
            Button("OK") {
                donationStore.clearBanner()
            }
        } message: {
            Text(donationStore.banner?.message ?? "")
        }
    }

    private var bannerIsPresented: Binding<Bool> {
        Binding(
            get: { donationStore.banner != nil },
            set: { isPresented in
                if isPresented == false {
                    donationStore.clearBanner()
                }
            }
        )
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
