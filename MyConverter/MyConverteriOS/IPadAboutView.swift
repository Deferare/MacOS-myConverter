#if os(iOS)
import SwiftUI

struct IPadAboutView: View {
    @ObservedObject var donationStore: DonationStore
    @State private var isShowingLicenses = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AboutInfoSection {
                        isShowingLicenses = true
                    }

                    DonationSupportSection(donationStore: donationStore)
                }
                .padding(20)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [Color.teal.opacity(0.25), Color(.systemBackground), Color.orange.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("About")
            .task {
                await donationStore.loadProductsIfNeeded()
            }
            .sheet(isPresented: $isShowingLicenses) {
                OpenSourceLicensesSheet(isPresented: $isShowingLicenses)
            }
        }
    }
}
#endif
