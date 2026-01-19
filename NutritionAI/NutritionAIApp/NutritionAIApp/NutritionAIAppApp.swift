import SwiftUI

@main
struct NutritionAIAppApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                AppContentView()
                
                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

struct SplashScreen: View {
    @State private var animate = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.6, blue: 0.85),
                    Color(red: 0.4, green: 0.75, blue: 0.7),
                    Color(red: 0.5, green: 0.85, blue: 0.6)
                ],
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            
            // Decorative circles
            GeometryReader { geometry in
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 3)
                    .offset(x: -100, y: -50)
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 3)
                    .offset(x: geometry.size.width - 80, y: geometry.size.height - 200)
            }
            
            VStack(spacing: 24) {
                // Animated logo
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                    
                    // Inner circle
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    // Icon
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        pulseScale = 1.5
                    }
                }
                
                VStack(spacing: 8) {
                    Text("NutritionAI")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Smart Food Tracking")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}
