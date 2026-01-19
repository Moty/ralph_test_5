import SwiftUI

/// View shown to guest users instead of the History tab
/// Encourages them to register to access meal tracking history
public struct GuestHistoryView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                AppGradients.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppGradients.primary.opacity(0.2))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundStyle(AppGradients.primary)
                    }
                    
                    // Title and description
                    VStack(spacing: 16) {
                        Text("Meal History")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Create a free account to track and view your meal history across all your devices.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Benefits list
                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow(icon: "icloud.fill", text: "Sync meals across all devices")
                        benefitRow(icon: "clock.arrow.circlepath", text: "View your complete meal history")
                        benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Track nutrition over time")
                        benefitRow(icon: "lock.shield.fill", text: "Keep your data safe and secure")
                    }
                    .padding(24)
                    .glassMorphism(cornerRadius: 20)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Register button
                    Button(action: { authService.logout() }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Create Free Account")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppGradients.primary)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: AppColors.primaryGradientStart.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    
                    Text("You're currently using the app as a guest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .navigationTitle("History")
        }
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppGradients.primary)
                .frame(width: 28)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#if DEBUG
struct GuestHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        GuestHistoryView()
            .environmentObject(AuthService())
    }
}
#endif
