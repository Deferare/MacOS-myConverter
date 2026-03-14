import Foundation
import OSLog
import StoreKit

extension DonationStore {
    static let supportProducts: [(id: String, amountText: String)] = [
        ("com.deferare.MyConverter.donation.1", "$1"),
        ("com.deferare.MyConverter.donation.3", "$3"),
        ("com.deferare.MyConverter.donation.5", "$5")
    ]

    static let productIDs: [String] = supportProducts.map(\.id)

    static let amountTextByProductID = Dictionary(
        uniqueKeysWithValues: supportProducts.map { ($0.id, $0.amountText) }
    )

    static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.deferare.MyConverter",
        category: "DonationStore"
    )

    static var appBundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle.id"
    }

    static var requestedProductIDs: String {
        productIDs.joined(separator: ",")
    }

    func suggestedAmountText(for productID: String) -> String {
        Self.amountTextByProductID[productID] ?? "Support"
    }
}
