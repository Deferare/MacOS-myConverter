import StoreKit
import SwiftUI

struct DonationSupportSection: View {
    @ObservedObject var donationStore: DonationStore
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)
    ]

    var body: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 18) {
                AboutSectionHeader(
                    title: "Support Development",
                    subtitle: "MyConverter is a labor of love. If it helps your workflow, you can support continued development here.",
                    systemImage: "heart.circle"
                )

                if donationStore.isLoadingProducts {
                    AboutInlineStatusRow(
                        title: "Loading support options",
                        message: "Connecting to the App Store.",
                        showsProgress: true
                    )
                } else if donationStore.products.isEmpty {
                    Button {
                        Task {
                            await donationStore.loadProducts()
                        }
                    } label: {
                        AboutMetadataRow(
                            title: "Reload Support Options",
                            value: "Try fetching the available App Store support products again.",
                            systemImage: "arrow.clockwise",
                            trailingSystemImage: "chevron.right"
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(donationStore.products, id: \.id) { product in
                            Button {
                                Task {
                                    await donationStore.purchase(product)
                                }
                            } label: {
                                donationButtonContent(for: product)
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                donationStore.isLoadingProducts ||
                                (donationStore.purchasingProductID != nil && donationStore.purchasingProductID != product.id)
                            )
                        }
                    }

                    AboutInlineStatusRow(
                        title: "Thank you",
                        message: "Your support helps keep the app free and actively maintained."
                    )
                }

                if let statusMessage = donationStore.statusMessage {
                    AboutInlineStatusRow(
                        title: donationStore.statusIsError ? "Support issue" : "App Store status",
                        message: statusMessage,
                        isError: donationStore.statusIsError
                    )
                }
            }
        }
    }

    private func donationButtonContent(for product: Product) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text(donationStore.suggestedAmountText(for: product.id))
                    .font(.system(size: 30, weight: .black))

                Spacer()

                if donationStore.purchasingProductID == product.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("One-time tip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Support the project")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(donationButtonBackground)
        .opacity(buttonOpacity(for: product))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var donationButtonBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func buttonOpacity(for product: Product) -> Double {
        if let purchasingProductID = donationStore.purchasingProductID,
           purchasingProductID != product.id {
            return 0.45
        }
        return 1
    }
}
