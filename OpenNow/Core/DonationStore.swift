import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class DonationStore {
    struct DonationTier: Identifiable, Hashable {
        let id: String
        let productID: String
        let fallbackAmount: Decimal
        let title: String
        let caption: String
    }

    enum PurchaseBanner: Equatable {
        case success(String)
        case pending(String)
        case info(String)
        case error(String)

        var title: String {
            switch self {
            case .success:
                "Thanks for supporting OpenNow"
            case .pending:
                "Purchase Pending"
            case .info:
                "In-App Purchase Unavailable"
            case .error:
                "Purchase Failed"
            }
        }

        var message: String {
            switch self {
            case .success(let message), .pending(let message), .info(let message), .error(let message):
                message
            }
        }
    }

    private static let featuredDefinitions = [
        DonationTier(
            id: "tip-1",
            productID: "com.dahengchen.OpenNow.tip.1",
            fallbackAmount: 0.99,
            title: "Small",
            caption: "Entry amount."
        ),
        DonationTier(
            id: "tip-6",
            productID: "com.dahengchen.OpenNow.tip.6",
            fallbackAmount: 1.99,
            title: "Standard",
            caption: "Default amount."
        ),
        DonationTier(
            id: "tip-9",
            productID: "com.dahengchen.OpenNow.tip.9",
            fallbackAmount: 2.99,
            title: "Generous",
            caption: "Higher amount."
        )
    ]

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private(set) var productsByID: [String: Product] = [:]
    private(set) var isLoadingProducts = false
    private(set) var activePurchaseProductID: String?
    var banner: PurchaseBanner?

    var featuredTiers: [DonationTier] {
        Self.featuredDefinitions
    }

    var hasLoadedProducts: Bool {
        productsByID.isEmpty == false
    }

    func loadProductsIfNeeded() async {
        guard productsByID.isEmpty else {
            return
        }

        await refreshProducts()
    }

    func refreshProducts() async {
        guard isLoadingProducts == false else {
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let productIDs = Self.featuredDefinitions.map(\.productID)
            let products = try await Product.products(for: productIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

            if products.isEmpty {
                banner = .info("No support purchase products are configured for this build yet. Connect these product IDs in App Store Connect or attach a StoreKit configuration for local testing.")
            }
        } catch {
            banner = .error("OpenNow couldn't load support purchase products right now. \(error.localizedDescription)")
        }
    }

    func displayPrice(for tier: DonationTier) -> String {
        if let product = productsByID[tier.productID] {
            return product.displayPrice
        }

        let amount = NSDecimalNumber(decimal: tier.fallbackAmount)
        return currencyFormatter.string(from: amount) ?? "\(tier.fallbackAmount)"
    }

    func isPurchasing(_ tier: DonationTier) -> Bool {
        activePurchaseProductID == tier.productID
    }

    func purchase(_ tier: DonationTier) async {
        if productsByID[tier.productID] == nil {
            await refreshProducts()
        }

        guard let product = productsByID[tier.productID] else {
            banner = .info("This support purchase tier isn't configured yet for the current build. Add \(tier.productID) in App Store Connect or a local StoreKit file before testing purchases.")
            return
        }

        activePurchaseProductID = tier.productID
        defer { activePurchaseProductID = nil }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                banner = .success("Your \(displayPrice(for: tier)) support purchase was received.")
            case .pending:
                banner = .pending("Your purchase is waiting for approval or App Store processing.")
            case .userCancelled:
                break
            @unknown default:
                banner = .error("OpenNow hit an unknown App Store purchase state.")
            }
        } catch {
            banner = .error(error.localizedDescription)
        }
    }

    func clearBanner() {
        banner = nil
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

private enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "The App Store transaction couldn't be verified."
        }
    }
}
