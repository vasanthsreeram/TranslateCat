import Foundation
import RevenueCat

/// TranslateCat Pro: RevenueCat setup, the live customer info, and whether Pro is unlocked.
@MainActor
@Observable
final class SubscriptionModel {
    // Test Store key for the demo. Swap in the App Store (appl_…) key before shipping.
    static let apiKey = "test_usRpcveWECEaSaQwkGxKEqhLrFp"
    static let entitlementID = "translatecat_pro"

    private(set) var customerInfo: CustomerInfo?
    private(set) var offerings: Offerings?
    private(set) var isWorking = false
    var errorMessage: String?

    /// True while the translatecat_pro entitlement is active (monthly, yearly, or lifetime).
    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementID]?.isActive == true
    }

    var proEntitlement: EntitlementInfo? {
        customerInfo?.entitlements[Self.entitlementID]
    }

    /// Packages in the current offering, e.g. monthly, yearly, and lifetime.
    var availablePackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Self.apiKey)

        Task { await observeCustomerInfo() }
        Task { await loadOfferings() }
    }

    /// RevenueCat pushes a fresh CustomerInfo whenever purchases, restores, renewals, or expirations happen.
    private func observeCustomerInfo() async {
        for await info in Purchases.shared.customerInfoStream {
            customerInfo = info
        }
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func loadOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Buys a package directly. The RevenueCat paywall handles this itself; this is for custom purchase buttons.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            customerInfo = result.customerInfo
            return isPro
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func restorePurchases() async {
        isWorking = true
        defer { isWorking = false }
        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            if !isPro {
                errorMessage = "No TranslateCat Pro purchase was found for this Apple Account."
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        guard let code = error as? RevenueCat.ErrorCode else { return error.localizedDescription }
        switch code {
        case .networkError, .offlineConnectionError:
            return "Couldn’t reach the App Store. Check your connection and try again."
        case .purchaseNotAllowedError:
            return "Purchases aren’t allowed on this device."
        case .paymentPendingError:
            return "Your purchase is pending approval. Pro unlocks as soon as it goes through."
        case .productAlreadyPurchasedError:
            return "You already own this. Try Restore Purchases."
        case .configurationError:
            return "Subscriptions aren’t set up yet. Please try again later."
        default:
            return code.localizedDescription
        }
    }
}
