import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var animateGradient = false
    
    let apiService: APIService
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    colors: animateGradient ? [
                        Color(red: 0.3, green: 0.8, blue: 0.6),
                        Color(red: 0.4, green: 0.6, blue: 0.85),
                        Color(red: 0.6, green: 0.5, blue: 0.9)
                    ] : [
                        Color(red: 0.6, green: 0.5, blue: 0.9),
                        Color(red: 0.3, green: 0.8, blue: 0.6),
                        Color(red: 0.4, green: 0.6, blue: 0.85)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                        animateGradient = true
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Create Account")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Join NutritionAI to track your meals")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        // Registration form card
                        VStack(spacing: 18) {
                            // Name field
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("Name", text: $name)
                                    .textContentType(.name)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            
                            // Email field
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
                            
                            // Password field
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                SecureField("Password", text: $password)
                                    .textContentType(.newPassword)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            
                            // Confirm password field
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            
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
                            
                            Button(action: handleRegister) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Create Account")
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
                            
                            Button(action: { dismiss() }) {
                                HStack {
                                    Text("Already have an account?")
                                        .foregroundColor(.secondary)
                                    Text("Login")
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
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarItems(leading: Button(action: { dismiss() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
            })
        }
    }
    
    private func handleRegister() {
        errorMessage = nil
        
        // Validation
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "All fields are required"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (token, user) = try await apiService.register(email: email, password: password, name: name)
                await MainActor.run {
                    authService.register(token: token, user: user)
                    isLoading = false
                    dismiss()
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
                        errorMessage = "Registration failed. Please try again."
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
