import Foundation
import StoreKit

@MainActor
@Observable
final class Store {
    enum Plan: String, CaseIterable {
        case yearly = "com.sleepingbird.premium.yearly"
        case monthly = "com.sleepingbird.premium.monthly"
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInProgress = false
    private(set) var hasLoadedEntitlements = false

    var isPremium: Bool { !purchasedProductIDs.isEmpty }

    init() {
        observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshPurchased()
            hasLoadedEntitlements = true
        }
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(
                for: Plan.allCases.map(\.rawValue)
            )
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshPurchased()
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase failed: \(error)")
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshPurchased()
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
