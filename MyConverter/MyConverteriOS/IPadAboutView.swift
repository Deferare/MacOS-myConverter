#if os(iOS)
import SwiftUI
import UIKit

struct IPadAboutView: View {
    @State private var isShowingLicenses = false

    var body: some View {
        ZStack {
            IPadAboutBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    IPadAboutHeroSection(appVersionText: appVersionText)

                    AboutInfoSection {
                        isShowingLicenses = true
                    }

                    Text("Built with SwiftUI & FFmpeg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, IPadAboutThemeMetrics.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, IPadAboutThemeMetrics.verticalPadding)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("About")
        .sheet(isPresented: $isShowingLicenses) {
            OpenSourceLicensesSheet(isPresented: $isShowingLicenses)
        }
        .tint(.blue)
    }

    private var appVersionText: String {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty else {
            return "Version"
        }

        return "Version \(shortVersion)"
    }
}
#endif
