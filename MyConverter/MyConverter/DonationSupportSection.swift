import StoreKit
import SwiftUI

struct DonationSupportSection: View {
    @ObservedObject var donationStore: DonationStore

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
                ForEach(Array(donationStore.products.enumerated()), id: \.element.id) { index, product in
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

                    if index < donationStore.products.count - 1 {
                        AboutSectionDivider()
                    }
                }

                AboutSectionDivider()

                Text("Your support helps keep the app free and actively maintained.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let statusMessage = donationStore.statusMessage {
                    AboutSectionDivider()

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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(donationStore.suggestedAmountText(for: product.id))
                    .font(.system(size: 30, weight: .black))

                Text("One-time tip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Support the project")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("One tap, one-time contribution")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(buttonOpacity(for: product))
        .contentShape(Rectangle())
    }

    private func buttonOpacity(for product: Product) -> Double {
        if let purchasingProductID = donationStore.purchasingProductID,
           purchasingProductID != product.id {
            return 0.45
        }
        return 1
    }
}
