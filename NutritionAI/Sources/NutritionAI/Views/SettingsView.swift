import SwiftUI

public struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthService
    @State private var tempURL: String = ""
    @State private var showSaved = false
    @State private var showLogoutConfirm = false
    @State private var isSyncing = false
    
    let apiService: APIService
    
    // Admin email addresses that can see advanced settings
    private let adminEmails = ["moty.moshin@gmail.com"]
    
    private var isAdmin: Bool {
        guard let email = authService.currentUser?.email else { return false }
        return adminEmails.contains(email.lowercased())
    }
    
    public init(apiService: APIService) {
        self.apiService = apiService
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                AppGradients.background
                    .ignoresSafeArea()
                
                Form {
                    // Admin-only sections
                    if isAdmin {
                        Section {
                            TextField("Backend URL", text: $tempURL)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            
                            Text("Current: \(settings.backendURL)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } header: {
                            Label("Server Configuration", systemImage: "server.rack")
                        } footer: {
                            Text("Enter the backend server URL including port (e.g., http://192.168.1.100:3000)")
                        }
                        
                        Section {
                            Button(action: {
                                if !tempURL.isEmpty {
                                    settings.backendURL = tempURL
                                    showSaved = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showSaved = false
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppGradients.primary)
                                    Text("Save URL")
                                }
                            }
                            .disabled(tempURL.isEmpty)
                            
                            if showSaved {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.primaryGradientStart)
                                    Text("URL Saved")
                                        .foregroundColor(AppColors.primaryGradientStart)
                                }
                            }
                        }
                        
                        Section {
                            Picker("AI Model", selection: $settings.geminiModel) {
                                ForEach(settings.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .tint(AppColors.primaryGradientEnd)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommendations:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("• gemini-2.0-flash: ⭐ Unlimited quota, fast")
                            Text("• gemini-2.0-flash-lite: Unlimited, fastest")
                            Text("• gemini-2.5-flash-lite: Unlimited, balanced")
                            Text("• gemini-3-flash: Newest model (10K/day)")
                            Text("• gemini-2.5-pro: Best accuracy (10K/day)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } header: {
                        Label("AI Model Selection", systemImage: "brain")
                    }
                    
                    Section {
                        Button(action: {
                            settings.setLocalhost()
                            tempURL = settings.backendURL
                        }) {
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundStyle(AppGradients.primary)
                                Text("Use Localhost (Simulator)")
                            }
                        }
                        
                        Button(action: {
                            settings.resetToDefault()
                            tempURL = settings.backendURL
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(AppGradients.primary)
                                Text("Reset to Default")
                            }
                        }
                    } header: {
                        Label("Quick Actions", systemImage: "bolt.fill")
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Finding Your Mac's IP:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("1. Open Terminal on your Mac")
                            Text("2. Run: ifconfig | grep \"inet \"")
                            Text("3. Look for an address like 192.168.x.x")
                            Text("4. Use http://YOUR-IP:3000")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } header: {
                        Text("Help")
                    }
                    } // End of admin-only sections
                
                // Appearance Section - available to everyone
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose how NutritionAI looks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Theme", selection: Binding(
                            get: { themeManager.colorScheme == nil ? 0 : (themeManager.colorScheme == .light ? 1 : 2) },
                            set: { value in
                                switch value {
                                case 1: themeManager.colorScheme = .light
                                case 2: themeManager.colorScheme = .dark
                                default: themeManager.colorScheme = nil
                                }
                            }
                        )) {
                            Text("System").tag(0)
                            Text("Light").tag(1)
                            Text("Dark").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                }
                
                // Data Sync section - only for registered users
                if authService.isRegisteredUser {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: "icloud.fill")
                                            .foregroundStyle(AppGradients.primary)
                                        Text("Cloud Sync")
                                            .font(.headline)
                                    }
                                    if let lastSync = syncService.lastSyncDate {
                                        Text("Last synced: \(formatSyncDate(lastSync))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Never synced")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if syncService.isSyncing {
                                ProgressView()
                                    .tint(AppColors.primaryGradientEnd)
                            }
                        }
                        
                        if let error = syncService.syncError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Button {
                            Task {
                                isSyncing = true
                                do {
                                    try await syncService.syncFromCloud()
                                } catch {
                                    print("Sync error: \(error)")
                                }
                                isSyncing = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppGradients.primary)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(syncService.isSyncing)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                    
                    Text("Meals are automatically backed up to the cloud when you're logged in. Use sync to fetch meals from other devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Label("Data Sync", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
                } else {
                    // Guest mode - show upgrade prompt
                    Section {
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "icloud.slash.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            
                            Text("Cloud Sync Unavailable")
                                .font(.headline)
                            
                            Text("Create a free account to sync your meals across all your devices and never lose your nutrition data.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                authService.logout()
                            } label: {
                                Text("Create Free Account")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppGradients.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Label("Cloud Sync", systemImage: "icloud.fill")
                    }
                }
                
                // Account section - different for guests vs registered users
                Section {
                    if authService.isGuest {
                        Button {
                            authService.logout()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.badge.plus")
                                Text("Create Free Account")
                                Spacer()
                            }
                            .foregroundStyle(AppGradients.primary)
                        }
                    } else {
                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Logout")
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Label("Account", systemImage: "person.circle.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .onAppear {
                tempURL = settings.backendURL
                syncService.configure(apiService: apiService, authService: authService)
            }
            .confirmationDialog("Are you sure you want to logout?", isPresented: $showLogoutConfirm) {
                Button("Logout", role: .destructive) {
                    authService.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            }
        }
    }
    
    private func formatSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(apiService: APIService())
            .environmentObject(AuthService())
    }
}
#endif
