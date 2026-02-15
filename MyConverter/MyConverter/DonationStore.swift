import Combine
import Foundation
import StoreKit

@MainActor
final class DonationStore: ObservableObject {
    static let productIDs: [String] = [
        "com.deferare.MyConverter.donation.1",
        "com.deferare.MyConverter.donation.3",
        "com.deferare.MyConverter.donation.5"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false

    private var hasLoadedProducts = false

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
                (idOrder[lhs.id] ?? .max) < (idOrder[rhs.id] ?? .max)
            }
            hasLoadedProducts = true
            statusMessage = products.isEmpty ? "후원 상품을 찾지 못했습니다. App Store Connect 상품 ID를 확인해주세요." : nil
            statusIsError = products.isEmpty
        } catch {
            statusMessage = "후원 상품을 불러오지 못했습니다: \(error.localizedDescription)"
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
                let transaction = try Self.checkVerified(verificationResult)
                await transaction.finish()
                statusMessage = "후원 감사합니다! 앱을 계속 무료로 유지하는 데 큰 도움이 됩니다."
            case .pending:
                statusMessage = "결제가 승인 대기 중입니다."
            case .userCancelled:
                statusMessage = "결제가 취소되었습니다."
            @unknown default:
                statusMessage = "알 수 없는 결제 상태가 발생했습니다."
                statusIsError = true
            }
        } catch {
            statusMessage = "결제 처리 중 오류가 발생했습니다: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    func suggestedAmountText(for productID: String) -> String {
        switch productID {
        case "com.deferare.MyConverter.donation.1":
            return "$1"
        case "com.deferare.MyConverter.donation.3":
            return "$3"
        case "com.deferare.MyConverter.donation.5":
            return "$5"
        default:
            return "Support"
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw DonationStoreError.failedVerification
        }
    }

    private enum DonationStoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "결제 검증에 실패했습니다."
        }
    }
}
