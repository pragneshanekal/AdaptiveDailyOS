import SwiftUI

struct WelcomeScreen: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 12) {
                    Text("AdaptiveDailyOS")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Build habits that adapt to you.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                featureRow(icon: "calendar.badge.checkmark", text: "Track habits every day")
                featureRow(icon: "flame.fill",               text: "Build streaks that motivate")
                featureRow(icon: "chart.bar.fill",           text: "See your progress over time")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                currentPage = 1
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

#Preview {
    WelcomeScreen(currentPage: .constant(0))
}
