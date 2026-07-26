
import Foundation
import PostHog
import StoreKit

@MainActor
@Observable
final class Store {
    enum Plan: String, CaseIterable {
        case yearly = "com.alizetech.arperbird.premium.yearly"
        case monthly = "com.alizetech.arperbird.premium.monthly"

        var shortName: String {
            switch self {
            case .yearly: return "yearly"
            case .monthly: return "monthly"
            }
        }
    }

    enum StoreError: LocalizedError, Identifiable {
        case purchase, verification, restore

        var id: String {
            switch self {
            case .purchase: return "purchase"
            case .verification: return "verification"
            case .restore: return "restore"
            }
        }

        var errorDescription: String? {
            switch self {
            case .purchase:
                return String(localized: "store.error.purchase")
            case .verification:
                return String(localized: "store.error.verification")
            case .restore:
                return String(localized: "store.error.restore")
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInProgress = false
    private(set) var restoreInProgress = false
    private(set) var hasLoadedEntitlements = false
    /// Product IDs the user is still eligible to start the introductory free
    /// trial on. Empty until `refreshIntroEligibility()` runs — which also means
    /// an unresolved state reads as "not eligible", so the paywall never
    /// promises a trial it hasn't confirmed.
    private(set) var introEligibleProductIDs: Set<String> = []
    var lastError: StoreError?

    var isPremium: Bool { !purchasedProductIDs.isEmpty }

    /// Whether saving a *new* tracker has to pass the paywall first. The free
    /// tier allows exactly one tracker at a time: the first save goes through
    /// untouched, and only a second one (`existingTrackerCount >= 1`) is
    /// interrupted — so a free user who deletes their tracker can create
    /// another. We wait for `hasLoadedEntitlements` so premium users are never
    /// told they need to pay before their StoreKit entitlements have resolved.
    func requiresPaywall(existingTrackerCount: Int) -> Bool {
        existingTrackerCount >= 1 && hasLoadedEntitlements && !isPremium
    }

    init() {
        observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshPurchased()
            // Resolve eligibility before flipping the entitlements barrier so the
            // paywall (gated on `hasLoadedEntitlements`) always opens with a
            // determined CTA — no flash of one label flipping to the other.
            await refreshIntroEligibility()
            hasLoadedEntitlements = true
        }
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    /// Whether the user can still start the introductory free trial on `plan`.
    func isEligibleForIntroOffer(_ plan: Plan) -> Bool {
        introEligibleProductIDs.contains(plan.rawValue)
    }

    /// Recomputes intro-offer eligibility for the loaded products. Safe to call
    /// repeatedly: it builds the new set before assigning, so the CTA keeps its
    /// current label until a *different* answer lands rather than blinking
    /// through an empty state. No-op when products haven't loaded yet.
    ///
    /// Eligibility is a snapshot with no push updates, so it has to be re-pulled
    /// at every moment it could have gone stale — otherwise the paywall keeps
    /// offering a free trial StoreKit will refuse to honour at checkout.
    func refreshIntroEligibility() async {
        guard !products.isEmpty else { return }
        var eligible: Set<String> = []
        for product in products where await isEligibleForIntroTrial(product) {
            eligible.insert(product.id)
        }
        introEligibleProductIDs = eligible
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(
                for: Plan.allCases.map(\.rawValue)
            )
        } catch {
            // No user-facing error here: this runs at launch and on paywall
            // appearance, where redacted prices and a disabled CTA already
            // convey the failure. Surfacing it would pop a stale modal.
            PostHogSDK.shared.capture("products_load_failed")
            PostHogSDK.shared.captureException(error)
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        lastError = nil
        let properties = purchaseProperties(for: product)
        let isTrial = await isEligibleForIntroTrial(product)
        PostHogSDK.shared.capture("purchase_started", properties: properties)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await refreshPurchased()
                    await transaction.finish()
                    // Fires at trial start (paid $0), not at conversion —
                    // so no revenue here. `is_trial` separates trial-starts
                    // from direct paid purchases (intro offer already used).
                    var started = properties
                    started["is_trial"] = isTrial
                    PostHogSDK.shared.capture(
                        "subscription_started",
                        properties: started
                    )
                    return true
                } catch {
                    PostHogSDK.shared.capture(
                        "purchase_verification_failed",
                        properties: properties
                    )
                    PostHogSDK.shared.captureException(
                        error,
                        properties: properties
                    )
                    lastError = .verification
                    return false
                }
            case .userCancelled:
                PostHogSDK.shared.capture(
                    "purchase_cancelled",
                    properties: properties
                )
                return false
            case .pending:
                PostHogSDK.shared.capture(
                    "purchase_pending",
                    properties: properties
                )
                return false
            @unknown default:
                return false
            }
        } catch {
            PostHogSDK.shared.capture("purchase_failed", properties: properties)
            PostHogSDK.shared.captureException(error, properties: properties)
            lastError = .purchase
            return false
        }
    }

    /// Restores entitlements via StoreKit — the source of truth for `isPremium`.
    /// Returns whether the sync succeeded; on failure `lastError` is set and
    /// `restore_completed` is not emitted.
    @discardableResult
    func restore() async -> Bool {
        restoreInProgress = true
        defer { restoreInProgress = false }
        PostHogSDK.shared.capture("restore_started")
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            PostHogSDK.shared.capture("restore_failed")
            PostHogSDK.shared.captureException(error)
            lastError = .restore
            return false
        }
        await refreshPurchased()
        PostHogSDK.shared.capture(
            "restore_completed",
            properties: [
                "restored_count": purchasedProductIDs.count,
                "is_premium": isPremium,
            ]
        )
        return true
    }

    /// Whether this purchase will apply the introductory free trial, i.e. the
    /// product offers one and the user is still eligible. False once the trial
    /// has been used, in which case the purchase is charged immediately.
    private func isEligibleForIntroTrial(_ product: Product) async -> Bool {
        guard let subscription = product.subscription,
            subscription.introductoryOffer != nil
        else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    private func purchaseProperties(for product: Product) -> [String: Any] {
        [
            "product_id": product.id,
            "plan": Plan(rawValue: product.id)?.shortName ?? product.id,
            "price": NSDecimalNumber(decimal: product.price).doubleValue,
            "currency": product.priceFormatStyle.currencyCode,
        ]
    }

    func refreshPurchased() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                transaction.revocationDate == nil
            else { continue }
            ids.insert(transaction.productID)
        }
        purchasedProductIDs = ids
    }

    private func observeTransactionUpdates() {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.checkVerified(result)
                else { continue }
                await self.refreshPurchased()
                await transaction.finish()
            }
        }
    }

    nonisolated private func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}
