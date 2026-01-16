import SwiftUI

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var colorScheme: ColorScheme? {
        didSet {
            if let scheme = colorScheme {
                UserDefaults.standard.set(scheme == .dark ? "dark" : "light", forKey: "appColorScheme")
            } else {
                UserDefaults.standard.removeObject(forKey: "appColorScheme")
            }
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appColorScheme") {
            colorScheme = saved == "dark" ? .dark : .light
        } else {
            colorScheme = nil // System default
        }
    }
    
    var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    func toggle() {
        colorScheme = (colorScheme == .dark) ? .light : .dark
    }
}

// MARK: - App Color Palette
struct AppColors {
    // Primary gradient colors - softer, easier on eyes
    static let primaryGradientStart = Color(red: 0.35, green: 0.65, blue: 0.55) // Soft sage green
    static let primaryGradientEnd = Color(red: 0.25, green: 0.50, blue: 0.70)   // Muted ocean blue
    
    // Accent colors - toned down
    static let accent = Color(red: 0.85, green: 0.45, blue: 0.50)              // Soft coral
    static let accentSecondary = Color(red: 0.90, green: 0.60, blue: 0.40)     // Muted peach
    
    // Card gradient colors - softer pastels
    static let cardGradient1Start = Color(red: 0.45, green: 0.60, blue: 0.75)  // Soft sky blue
    static let cardGradient1End = Color(red: 0.55, green: 0.50, blue: 0.70)    // Soft lavender
    
    static let cardGradient2Start = Color(red: 0.75, green: 0.55, blue: 0.58)  // Dusty rose
    static let cardGradient2End = Color(red: 0.85, green: 0.65, blue: 0.50)    // Soft peach
    
    static let cardGradient3Start = Color(red: 0.45, green: 0.65, blue: 0.60)  // Soft teal
    static let cardGradient3End = Color(red: 0.40, green: 0.55, blue: 0.65)    // Slate blue
    
    static let cardGradient4Start = Color(red: 0.70, green: 0.58, blue: 0.75)  // Soft lavender
    static let cardGradient4End = Color(red: 0.58, green: 0.48, blue: 0.68)    // Muted violet
    
    // Nutrition-specific colors - slightly muted for less eye strain
    static let calories = Color(red: 0.90, green: 0.50, blue: 0.45)           // Soft red-coral
    static let protein = Color(red: 0.40, green: 0.60, blue: 0.80)            // Steel blue
    static let carbs = Color(red: 0.90, green: 0.70, blue: 0.35)              // Soft amber
    static let fat = Color(red: 0.75, green: 0.55, blue: 0.78)                // Soft purple
    
    // Light mode background colors - warmer, easier on eyes
    static let backgroundPrimary = Color(red: 0.96, green: 0.95, blue: 0.93)  // Warm off-white
    static let backgroundSecondary = Color(red: 0.98, green: 0.97, blue: 0.95) // Cream white
    static let cardBackground = Color(red: 0.99, green: 0.98, blue: 0.97)     // Soft white
    
    // Dark mode variants - comfortable dark theme
    static let darkBackgroundPrimary = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let darkBackgroundSecondary = Color(red: 0.14, green: 0.15, blue: 0.17)
    static let darkCardBackground = Color(red: 0.18, green: 0.19, blue: 0.22)
    
    // Dynamic colors that adapt to color scheme
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBackgroundPrimary : backgroundPrimary
    }
    
    static func cardBg(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardBackground : cardBackground
    }
    
    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.92) : Color(white: 0.15)
    }
    
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(white: 0.45)
    }
}

// MARK: - Gradient Definitions
struct AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Softer, eye-friendly background gradient for light mode
    static let background = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.95, blue: 0.93),  // Warm cream
            Color(red: 0.95, green: 0.94, blue: 0.92)   // Soft beige
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Dark mode background gradient
    static let darkBackground = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.11, blue: 0.13),
            Color(red: 0.12, green: 0.13, blue: 0.15)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // Adaptive background that works with color scheme
    static func adaptiveBackground(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark ? darkBackground : background
    }
    
    static let loginBackground = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.50, blue: 0.70),  // Muted blue
            Color(red: 0.35, green: 0.60, blue: 0.60),  // Soft teal
            Color(red: 0.40, green: 0.65, blue: 0.55)   // Sage green
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
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 8, x: 0, y: 4)
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Adaptive background gradient
                (colorScheme == .dark ? AppGradients.darkBackground : AppGradients.background)
                    .ignoresSafeArea()
                
                // Softer floating bubbles with reduced opacity
                AnimatedBubble(size: 200, color: AppColors.primaryGradientStart.opacity(colorScheme == .dark ? 0.15 : 0.25), delay: 0)
                    .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.2)
                
                AnimatedBubble(size: 150, color: AppColors.primaryGradientEnd.opacity(colorScheme == .dark ? 0.12 : 0.20), delay: 0.5)
                    .position(x: geometry.size.width * 0.9, y: geometry.size.height * 0.3)
                
                AnimatedBubble(size: 180, color: AppColors.accentSecondary.opacity(colorScheme == .dark ? 0.10 : 0.15), delay: 1)
                    .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.8)
                
                AnimatedBubble(size: 120, color: AppColors.accent.opacity(colorScheme == .dark ? 0.08 : 0.12), delay: 1.5)
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
