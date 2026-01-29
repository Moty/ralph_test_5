#if canImport(UIKit)
import SwiftUI

public struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    let apiService: APIService

    @State private var step: SetupStep = .dietType
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Diet templates
    @State private var templates: [DietTemplate] = []

    // Form data
    @State private var selectedDietType = "balanced"
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var age: String = ""
    @State private var gender = "male"
    @State private var activityLevel = "moderate"

    // Goals
    @State private var dailyCalorieGoal: Int = 2000
    @State private var dailyProteinGoal: Int = 100
    @State private var dailyCarbsGoal: Int = 250
    @State private var dailyFatGoal: Int = 67
    @State private var calculatedGoals: CalculateGoalsResponse?

    enum SetupStep {
        case dietType
        case metrics
        case goals
        case complete
    }

    public init(apiService: APIService) {
        self.apiService = apiService
    }

    public var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Progress indicator
                        progressIndicator

                        // Step content
                        switch step {
                        case .dietType:
                            dietTypeStep
                        case .metrics:
                            metricsStep
                        case .goals:
                            goalsStep
                        case .complete:
                            completeStep
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Set Up Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .complete {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadTemplates()
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach([SetupStep.dietType, .metrics, .goals], id: \.self) { s in
                Rectangle()
                    .fill(stepIndex(s) <= stepIndex(step)
                          ? AnyShapeStyle(AppGradients.primary)
                          : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
        .padding(.horizontal)
    }

    private func stepIndex(_ s: SetupStep) -> Int {
        switch s {
        case .dietType: return 0
        case .metrics: return 1
        case .goals: return 2
        case .complete: return 3
        }
    }

    // MARK: - Diet Type Step

    private var dietTypeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your Diet Type")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            if templates.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(templates) { template in
                    DietTemplateCard(
                        template: template,
                        isSelected: selectedDietType == template.dietType
                    ) {
                        selectDietType(template)
                    }
                }
            }

            Spacer(minLength: 20)

            Button(action: { step = .metrics }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(templates.isEmpty)
        }
    }

    private func selectDietType(_ template: DietTemplate) {
        selectedDietType = template.dietType
        dailyCalorieGoal = template.baselineCalories
        dailyProteinGoal = template.baselineProtein
        dailyCarbsGoal = template.baselineCarbs
        dailyFatGoal = template.baselineFat
    }

    // MARK: - Metrics Step

    private var metricsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Physical Metrics")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            Text("Enter your metrics to get personalized goals, or skip to use defaults.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    MetricField(label: "Weight (kg)", text: $weight, keyboardType: .decimalPad)
                    MetricField(label: "Height (cm)", text: $height, keyboardType: .decimalPad)
                }

                MetricField(label: "Age", text: $age, keyboardType: .numberPad)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .pickerStyle(.segmented)
                }
                .glassMorphism()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity Level")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Activity Level", selection: $activityLevel) {
                        Text("Sedentary").tag("sedentary")
                        Text("Light").tag("light")
                        Text("Moderate").tag("moderate")
                        Text("Active").tag("active")
                        Text("Very Active").tag("very_active")
                    }
                    .pickerStyle(.menu)
                }
                .glassMorphism()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            if !weight.isEmpty && !height.isEmpty && !age.isEmpty {
                Button(action: calculateGoals) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Calculate My Goals")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(gradient: AppGradients.secondary))
            }

            Spacer(minLength: 20)

            HStack(spacing: 12) {
                Button(action: { step = .dietType }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(gradient: AppGradients.secondary))

                Button(action: { step = .goals }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
            }
        }
    }

    // MARK: - Goals Step

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Daily Goals")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            if let calculated = calculatedGoals {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Goals calculated based on your metrics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            VStack(spacing: 16) {
                GoalSlider(label: "Daily Calories", value: $dailyCalorieGoal, range: 1000...4000, unit: "kcal")
                GoalSlider(label: "Daily Protein", value: $dailyProteinGoal, range: 30...300, unit: "g")
                GoalSlider(label: "Daily Carbs", value: $dailyCarbsGoal, range: 20...500, unit: "g")
                GoalSlider(label: "Daily Fat", value: $dailyFatGoal, range: 20...200, unit: "g")
            }

            Spacer(minLength: 20)

            HStack(spacing: 12) {
                Button(action: { step = .metrics }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(gradient: AppGradients.secondary))

                Button(action: saveProfile) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Save Profile")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Complete Step

    private var completeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppGradients.primary.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppGradients.primary)
            }

            Text("Profile Saved!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            Text("Your \(selectedTemplate?.name ?? "diet") profile has been set up. Start tracking your meals to see your progress!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button(action: { dismiss() }) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
        }
    }

    private var selectedTemplate: DietTemplate? {
        templates.first { $0.dietType == selectedDietType }
    }

    // MARK: - Actions

    private func loadTemplates() async {
        isLoading = true
        do {
            templates = try await apiService.fetchDietTemplates()
        } catch let error as APIError {
            switch error {
            case .serverError(let message):
                errorMessage = message
            default:
                errorMessage = "Failed to load diet templates"
            }
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        isLoading = false
    }

    private func calculateGoals() {
        guard let w = Double(weight), let h = Double(height), let a = Int(age) else { return }

        isLoading = true

        Task {
            do {
                let request = CalculateGoalsRequest(
                    weight: w,
                    height: h,
                    age: a,
                    gender: gender,
                    activityLevel: activityLevel,
                    dietType: selectedDietType
                )
                let response = try await apiService.calculateGoals(request)

                await MainActor.run {
                    calculatedGoals = response
                    dailyCalorieGoal = response.goals.calories
                    dailyProteinGoal = response.goals.protein
                    dailyCarbsGoal = response.goals.carbs
                    dailyFatGoal = response.goals.fat
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .serverError(let message):
                        errorMessage = message
                    default:
                        errorMessage = "Failed to calculate goals"
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

    private func saveProfile() {
        isLoading = true

        Task {
            do {
                var profileData = ProfileUpdateRequest()
                profileData.dietType = selectedDietType
                profileData.dailyCalorieGoal = dailyCalorieGoal
                profileData.dailyProteinGoal = dailyProteinGoal
                profileData.dailyCarbsGoal = dailyCarbsGoal
                profileData.dailyFatGoal = dailyFatGoal

                if let w = Double(weight) { profileData.weight = w }
                if let h = Double(height) { profileData.height = h }
                if let a = Int(age) { profileData.age = a }
                profileData.gender = gender
                profileData.activityLevel = activityLevel

                _ = try await apiService.updateProfile(profileData)

                await MainActor.run {
                    isLoading = false
                    step = .complete
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .serverError(let message):
                        errorMessage = message
                    default:
                        errorMessage = "Failed to save profile"
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

// MARK: - Helper Views

struct DietTemplateCard: View {
    let template: DietTemplate
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary(for: colorScheme))

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppGradients.primary)
                    }
                }

                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    MacroLabel(name: "P", value: "\(Int(template.proteinRatio * 100))%")
                    MacroLabel(name: "C", value: "\(Int(template.carbsRatio * 100))%")
                    MacroLabel(name: "F", value: "\(Int(template.fatRatio * 100))%")
                }
            }
            .padding()
            .glassMorphism()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.primaryGradientEnd : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MacroLabel: View {
    let name: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }
}

struct MetricField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("", text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct GoalSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary(for: colorScheme))

                Spacer()

                Text("\(value) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppGradients.primary)
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(AppColors.primaryGradientEnd)
        }
        .padding()
        .glassMorphism()
    }
}

#endif
