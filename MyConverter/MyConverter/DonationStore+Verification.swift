import Foundation
import StoreKit

extension DonationStore {
    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw DonationStoreError.failedVerification
        }
    }

    enum DonationStoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "Purchase verification failed."
        }
    }
}
