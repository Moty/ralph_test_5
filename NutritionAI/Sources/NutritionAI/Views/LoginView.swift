import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false
    @State private var animateGradient = false
    
    let apiService: APIService
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: animateGradient ? [
                        Color(red: 0.2, green: 0.5, blue: 0.9),
                        Color(red: 0.4, green: 0.7, blue: 0.75),
                        Color(red: 0.3, green: 0.8, blue: 0.6)
                    ] : [
                        Color(red: 0.3, green: 0.8, blue: 0.6),
                        Color(red: 0.2, green: 0.5, blue: 0.9),
                        Color(red: 0.4, green: 0.7, blue: 0.75)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                        animateGradient = true
                    }
                }
                
                // Decorative circles
                GeometryReader { geometry in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .blur(radius: 2)
                        .offset(x: -100, y: -50)
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 2)
                        .offset(x: geometry.size.width - 80, y: geometry.size.height - 200)
                }
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App icon and title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        
                        Text("NutritionAI")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Track your nutrition with AI")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Login form card
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                        }
                        
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: handleLogin) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .fontWeight(.bold)
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppGradients.primary)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: AppColors.primaryGradientStart.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading)
                        
                        Button(action: { showRegister = true }) {
                            HStack {
                                Text("Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text("Register")
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primaryGradientEnd)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView(apiService: apiService)
                    .environmentObject(authService)
            }
        }
    }
    
    private func handleLogin() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                let (token, user) = try await apiService.login(email: email, password: password)
                await MainActor.run {
                    authService.login(token: token, user: user)
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .serverError(let message):
                        errorMessage = message
                    case .noInternetConnection:
                        errorMessage = "No internet connection"
                    case .timeout:
                        errorMessage = "Request timed out"
                    default:
                        errorMessage = "Login failed. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "An unexpected error occurred"
                }
            }
        }
    }
}
