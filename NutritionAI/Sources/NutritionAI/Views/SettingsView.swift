import SwiftUI

public struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var tempURL: String = ""
    @State private var showSaved = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Backend URL", text: $tempURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    
                    Text("Current: \(settings.backendURL)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Server Configuration")
                } footer: {
                    Text("Enter the backend server URL including port (e.g., http://192.168.1.100:3000)")
                }
                
                Section {
                    Button("Save URL") {
                        if !tempURL.isEmpty {
                            settings.backendURL = tempURL
                            showSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSaved = false
                            }
                        }
                    }
                    .disabled(tempURL.isEmpty)
                    
                    if showSaved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("URL Saved")
                        }
                    }
                }
                
                Section {
                    Picker("AI Model", selection: $settings.geminiModel) {
                        ForEach(settings.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommendations:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("• gemini-2.5-flash: Fastest, good accuracy")
                        Text("• gemini-2.5-pro: Best accuracy, slower")
                        Text("• gemini-2.0-flash: Stable, reliable")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("AI Model Selection")
                }
                
                Section {
                    Button("Use Localhost (Simulator)") {
                        settings.setLocalhost()
                        tempURL = settings.backendURL
                    }
                    
                    Button("Reset to Default") {
                        settings.resetToDefault()
                        tempURL = settings.backendURL
                    }
                } header: {
                    Text("Quick Actions")
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
            }
            .navigationTitle("Settings")
            .onAppear {
                tempURL = settings.backendURL
            }
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
