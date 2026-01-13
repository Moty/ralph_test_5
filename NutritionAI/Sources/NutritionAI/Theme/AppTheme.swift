import SwiftUI

// MARK: - App Color Palette
struct AppColors {
    // Primary gradient colors
    static let primaryGradientStart = Color(red: 0.4, green: 0.8, blue: 0.6) // Fresh green
    static let primaryGradientEnd = Color(red: 0.2, green: 0.6, blue: 0.9)   // Ocean blue
    
    // Accent colors
    static let accent = Color(red: 0.95, green: 0.4, blue: 0.5)              // Coral pink
    static let accentSecondary = Color(red: 1.0, green: 0.6, blue: 0.3)      // Warm orange
    
    // Card gradient colors
    static let cardGradient1Start = Color(red: 0.3, green: 0.7, blue: 0.9)   // Sky blue
    static let cardGradient1End = Color(red: 0.5, green: 0.4, blue: 0.9)     // Purple
    
    static let cardGradient2Start = Color(red: 0.9, green: 0.5, blue: 0.6)   // Rose
    static let cardGradient2End = Color(red: 1.0, green: 0.7, blue: 0.4)     // Peach
    
    static let cardGradient3Start = Color(red: 0.4, green: 0.8, blue: 0.7)   // Teal
    static let cardGradient3End = Color(red: 0.3, green: 0.6, blue: 0.8)     // Ocean
    
    static let cardGradient4Start = Color(red: 0.8, green: 0.6, blue: 0.9)   // Lavender
    static let cardGradient4End = Color(red: 0.6, green: 0.4, blue: 0.8)     // Violet
    
    // Nutrition-specific colors
    static let calories = Color(red: 1.0, green: 0.45, blue: 0.35)           // Vibrant red-orange
    static let protein = Color(red: 0.3, green: 0.7, blue: 0.95)             // Bright blue
    static let carbs = Color(red: 1.0, green: 0.75, blue: 0.2)               // Golden yellow
    static let fat = Color(red: 0.85, green: 0.55, blue: 0.9)                // Soft purple
    
    // Background colors
    static let backgroundPrimary = Color(red: 0.97, green: 0.97, blue: 0.99)
    static let backgroundSecondary = Color.white
    static let cardBackground = Color.white
    
    // Dark mode variants
    static let darkBackgroundPrimary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let darkBackgroundSecondary = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let darkCardBackground = Color(red: 0.15, green: 0.15, blue: 0.2)
}

// MARK: - Gradient Definitions
struct AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let background = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.98, green: 0.95, blue: 0.98)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let loginBackground = LinearGradient(
        colors: [
            Color(red: 0.2, green: 0.6, blue: 0.85),
            Color(red: 0.4, green: 0.75, blue: 0.7),
            Color(red: 0.5, green: 0.85, blue: 0.6)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let welcomeHeader = LinearGradient(
        colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let cardGradients: [LinearGradient] = [
        LinearGradient(colors: [AppColors.cardGradient1Start, AppColors.cardGradient1End], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [AppColors.cardGradient2Start, AppColors.cardGradient2End], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [AppColors.cardGradient3Start, AppColors.cardGradient3End], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [AppColors.cardGradient4Start, AppColors.cardGradient4End], startPoint: .topLeading, endPoint: .bottomTrailing)
    ]
    
    static func cardGradient(at index: Int) -> LinearGradient {
        cardGradients[index % cardGradients.count]
    }
}

// MARK: - Glass Morphism Effect
struct GlassMorphismModifier: ViewModifier {
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Neumorphic Card
struct NeumorphicCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? AppColors.darkCardBackground : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0 : 0.7), radius: 10, x: -5, y: -5)
            )
    }
}

// MARK: - Gradient Card Style
struct GradientCardModifier: ViewModifier {
    let gradient: LinearGradient
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            )
    }
}

// MARK: - Animated Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Gradient Button Style
struct GradientButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    
    init(gradient: LinearGradient = AppGradients.primary) {
        self.gradient = gradient
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(gradient)
                    .shadow(color: AppColors.primaryGradientStart.opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .foregroundColor(.white)
            .fontWeight(.semibold)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Extensions
extension View {
    func glassMorphism(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassMorphismModifier(cornerRadius: cornerRadius))
    }
    
    func neumorphicCard() -> some View {
        modifier(NeumorphicCardModifier())
    }
    
    func gradientCard(_ gradient: LinearGradient) -> some View {
        modifier(GradientCardModifier(gradient: gradient))
    }
}

// MARK: - Animated Background Bubbles
struct AnimatedBubble: View {
    let size: CGFloat
    let color: Color
    let delay: Double
    
    @State private var animate = false
    
    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: size, height: size)
            .blur(radius: size * 0.3)
            .offset(y: animate ? -20 : 20)
            .animation(
                Animation.easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
            .onAppear {
                animate = true
            }
    }
}

struct AnimatedBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppGradients.background
                    .ignoresSafeArea()
                
                // Floating bubbles
                AnimatedBubble(size: 200, color: AppColors.primaryGradientStart, delay: 0)
                    .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.2)
                
                AnimatedBubble(size: 150, color: AppColors.primaryGradientEnd, delay: 0.5)
                    .position(x: geometry.size.width * 0.9, y: geometry.size.height * 0.3)
                
                AnimatedBubble(size: 180, color: AppColors.accentSecondary, delay: 1)
                    .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
                
                AnimatedBubble(size: 120, color: AppColors.accent, delay: 1.5)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.7)
            }
        }
    }
}

// MARK: - Decorative Wave
struct WaveShape: Shape {
    var offset: Double
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * 0.5
        let wavelength = width / 1.5
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / wavelength
            let y = midHeight + sin(relativeX * .pi * 2 + offset) * (height * 0.3)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct AnimatedWave: View {
    let color: Color
    let speed: Double
    
    @State private var offset: Double = 0
    
    var body: some View {
        WaveShape(offset: offset)
            .fill(color)
            .onAppear {
                withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                    offset = .pi * 2
                }
            }
    }
}
