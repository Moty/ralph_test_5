import SwiftUI

struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(AppGradients.primary)

                        Text("Welcome to NutritionAI")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        onboardingRow(icon: "camera.fill", title: "Capture a meal", detail: "Snap a photo to analyze nutrition instantly.")
                        onboardingRow(icon: "sparkles", title: "Review results", detail: "See calories, macros, and ingredients.")
                        onboardingRow(icon: "chart.line.uptrend.xyaxis", title: "Track progress", detail: "Build healthy habits over time.")
                    }
                    .padding(20)
                    .glassMorphism()

                    Spacer()

                    Button(action: onDismiss) {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GradientButtonStyle())
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func onboardingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppGradients.primary)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onDismiss: {})
    }
}
#endif