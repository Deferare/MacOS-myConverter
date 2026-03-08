import Combine
import Foundation
import OSLog
import StoreKit

@MainActor
final class DonationStore: ObservableObject {
    private static let supportProducts: [(id: String, amountText: String)] = [
        ("com.deferare.MyConverter.donation.1", "$1"),
        ("com.deferare.MyConverter.donation.3", "$3"),
        ("com.deferare.MyConverter.donation.5", "$5")
    ]
    static let productIDs: [String] = supportProducts.map(\.id)
    private static let amountTextByProductID = Dictionary(
        uniqueKeysWithValues: supportProducts.map { ($0.id, $0.amountText) }
    )
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.deferare.MyConverter",
        category: "DonationStore"
    )

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false

    private var hasLoadedProducts = false
    private var observedTransactionIDs = Set<Transaction.ID>()
    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = Task { [weak self] in
            await self?.observeTransactions()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProductsIfNeeded() async {
        guard !hasLoadedProducts else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(for: Self.productIDs)
            let idOrder = Dictionary(uniqueKeysWithValues: Self.productIDs.enumerated().map { ($1, $0) })

            products = fetchedProducts.sorted { lhs, rhs in
                if lhs.price != rhs.price {
                    return lhs.price < rhs.price
                }
                return (idOrder[lhs.id] ?? .max) < (idOrder[rhs.id] ?? .max)
            }
            hasLoadedProducts = true
            if products.isEmpty {
                Self.logger.error(
                    "App Store returned no support products. bundleID=\(Self.appBundleID, privacy: .public) productIDs=\(Self.requestedProductIDs, privacy: .public)"
                )
                statusMessage = "No support products are available from the App Store. Verify that the donation product IDs for \(Self.appBundleID) exist in App Store Connect and are approved for sale."
            } else {
                statusMessage = nil
            }
            statusIsError = products.isEmpty
        } catch {
            Self.logger.error("Failed to load support products: \(String(describing: error), privacy: .public)")
            statusMessage = "Could not load support products: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    func purchase(_ product: Product) async {
        guard purchasingProductID == nil else { return }

        purchasingProductID = product.id
        statusMessage = nil
        statusIsError = false

        defer { purchasingProductID = nil }

        do {
            let purchaseResult = try await product.purchase()
            switch purchaseResult {
            case .success(let verificationResult):
                try await handle(transactionResult: verificationResult, showsSuccessMessage: true)
            case .pending:
                statusMessage = "Your purchase is pending approval."
            case .userCancelled:
                statusMessage = "The purchase was cancelled."
            @unknown default:
                statusMessage = "An unknown purchase state occurred."
                statusIsError = true
            }
        } catch {
            statusMessage = "An error occurred while processing the purchase: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    func suggestedAmountText(for productID: String) -> String {
        Self.amountTextByProductID[productID] ?? "Support"
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw DonationStoreError.failedVerification
        }
    }

    private func observeTransactions() async {
        await consume(Transaction.unfinished)

        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            await consume(result)
        }
    }

    private func consume(_ transactions: Transaction.Transactions) async {
        for await result in transactions {
            guard !Task.isCancelled else { return }
            await consume(result)
        }
    }

    private func consume(_ result: VerificationResult<Transaction>) async {
        do {
            try await handle(transactionResult: result, showsSuccessMessage: true)
        } catch {
            statusMessage = "An error occurred while verifying the purchase: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func handle(
        transactionResult: VerificationResult<Transaction>,
        showsSuccessMessage: Bool
    ) async throws {
        let transaction = try Self.checkVerified(transactionResult)

        guard observedTransactionIDs.insert(transaction.id).inserted else { return }

        await transaction.finish()

        if Self.productIDs.contains(transaction.productID), showsSuccessMessage {
            statusMessage = "Thank you for your support. It helps keep the app free."
            statusIsError = false
        }
    }

    private enum DonationStoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "Purchase verification failed."
        }
    }

    private static var appBundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle.id"
    }

    private static var requestedProductIDs: String {
        productIDs.joined(separator: ",")
    }
}
