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

                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if donationStore.isLoadingProducts {
            AboutInlineStatusRow(
                title: "Loading support options",
                message: "Connecting to the App Store.",
                showsProgress: true
            )
        } else if donationStore.products.isEmpty {
            VStack(spacing: 0) {
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

                if let statusMessage = donationStore.statusMessage {
                    AboutSectionDivider()

                    AboutInlineStatusRow(
                        title: donationStore.statusIsError ? "Support issue" : "App Store status",
                        message: statusMessage,
                        isError: donationStore.statusIsError
                    )
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
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

                if donationStore.statusIsError,
                   let statusMessage = donationStore.statusMessage {
                    AboutSectionDivider()
                        .padding(.top, 18)

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
            HStack(alignment: .center, spacing: 8) {
                Text(donationStore.suggestedAmountText(for: product.id))
                    .font(.system(size: 34, weight: .heavy))

                if donationStore.purchasingProductID == product.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Support the project")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("One-time tip")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
