import StoreKit
import SwiftUI

struct DonationSupportSection: View {
    @ObservedObject var donationStore: DonationStore

    var body: some View {
        Text("Support Development")
            .font(.headline)

        Text("MyConverter is a labor of love. If you find it useful, consider supporting its continued development.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        if donationStore.isLoadingProducts {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading support options...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if donationStore.products.isEmpty {
            Button("Reload Support Options") {
                Task {
                    await donationStore.loadProducts()
                }
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
        } else {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(donationStore.products, id: \.id) { product in
                        Button {
                            Task {
                                await donationStore.purchase(product)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(donationStore.suggestedAmountText(for: product.id))
                                    .font(.system(size: 30, weight: .black))

                                if donationStore.purchasingProductID == product.id {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 82)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .disabled(
                            donationStore.isLoadingProducts ||
                            (donationStore.purchasingProductID != nil && donationStore.purchasingProductID != product.id)
                        )
                    }
                }
            }

            Text("Thank you for your support!")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }

        if let statusMessage = donationStore.statusMessage {
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(donationStore.statusIsError ? .red : .secondary)
        }
    }
}
