#if canImport(UIKit)
import SwiftUI

public struct DietProgressView: View {
    @Environment(\.colorScheme) var colorScheme

    let apiService: APIService

    @State private var selectedTab: ProgressTab = .today
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var needsSetup = false

    @State private var todayData: TodayProgressResponse?
    @State private var weekData: WeekProgressResponse?
    @State private var monthData: MonthlyProgressResponse?

    @State private var showingProfileSetup = false

    enum ProgressTab: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
    }

    public init(apiService: APIService) {
        self.apiService = apiService
    }

    public var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()

                if needsSetup {
                    needsSetupView
                } else {
                    VStack(spacing: 0) {
                        // Tab selector
                        Picker("Tab", selection: $selectedTab) {
                            ForEach(ProgressTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        // Content
                        ScrollView {
                            if isLoading {
                                loadingView
                            } else if let error = errorMessage {
                                errorView(error)
                            } else {
                                contentView
                            }
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingProfileSetup) {
                ProfileSetupView(apiService: apiService)
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: selectedTab) { _ in
            Task { await loadData() }
        }
    }

    private var needsSetupView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppGradients.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 45))
                    .foregroundStyle(AppGradients.primary)
            }

            Text("Set Up Your Profile")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))

            Text("To track your diet progress, you need to set up your diet profile first.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingProfileSetup = true }) {
                Text("Set Up Profile")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading progress...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Failed to load progress")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { Task { await loadData() } }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(GradientButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .glassMorphism()
        .padding(.horizontal)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .today:
            if let data = todayData {
                todayContent(data)
            }
        case .week:
            if let data = weekData {
                weekContent(data)
            }
        case .month:
            if let data = monthData {
                monthContent(data)
            }
        }
    }

    // MARK: - Today Content

    private func todayContent(_ data: TodayProgressResponse) -> some View {
        VStack(spacing: 20) {
            // Status card
            statusCard(data)

            // Macros
            sectionHeader(title: "Today's Macros", icon: "chart.bar.fill")
            macrosGrid(data)

            // Remaining
            sectionHeader(title: "Remaining Today", icon: "target")
            remainingGrid(data)

            // Suggestions
            if !data.suggestions.isEmpty {
                sectionHeader(title: "Next Meal Suggestions", icon: "lightbulb.fill")
                suggestionsSection(data.suggestions)
            }

            Spacer(minLength: 40)
        }
        .padding()
    }

    private func statusCard(_ data: TodayProgressResponse) -> some View {
        HStack {
            Image(systemName: data.progress.isOnTrack ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(data.progress.isOnTrack ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.progress.isOnTrack ? "On Track!" : "Needs Attention")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(for: colorScheme))

                Text("Compliance: \(Int(data.progress.complianceScore * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let netCarbs = data.progress.netCarbs {
                    Text("Net Carbs: \(netCarbs)g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .glassMorphism()
    }

    private func macrosGrid(_ data: TodayProgressResponse) -> some View {
        VStack(spacing: 12) {
            MacroProgressBar(
                label: "Calories",
                current: data.progress.totalCalories,
                goal: data.progress.goalCalories,
                unit: "",
                color: AppColors.primaryGradientEnd
            )

            MacroProgressBar(
                label: "Protein",
                current: data.progress.totalProtein,
                goal: data.progress.goalProtein,
                unit: "g",
                color: .green
            )

            MacroProgressBar(
                label: "Carbs",
                current: data.progress.totalCarbs,
                goal: data.progress.goalCarbs,
                unit: "g",
                color: .orange
            )

            MacroProgressBar(
                label: "Fat",
                current: data.progress.totalFat,
                goal: data.progress.goalFat,
                unit: "g",
                color: .purple
            )
        }
        .padding()
        .glassMorphism()
    }

    private func remainingGrid(_ data: TodayProgressResponse) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            RemainingCard(label: "Calories", value: data.remaining.calories, unit: "")
            RemainingCard(label: "Protein", value: data.remaining.protein, unit: "g")
            RemainingCard(label: "Carbs", value: data.remaining.carbs, unit: "g")
            RemainingCard(label: "Fat", value: data.remaining.fat, unit: "g")
        }
    }

    private func suggestionsSection(_ suggestions: [String]) -> some View {
        VStack(spacing: 12) {
            ForEach(suggestions.indices, id: \.self) { index in
                let suggestion = suggestions[index]
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppGradients.primary)
                        .font(.body)
                    
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .glassMorphism()
            }
        }
    }

    // MARK: - Week Content

    private func weekContent(_ data: WeekProgressResponse) -> some View {
        VStack(spacing: 20) {
            // Summary card
            if let summary = data.summary {
                weekSummaryCard(summary)
            }

            // Daily breakdown
            sectionHeader(title: "Daily Breakdown", icon: "calendar")

            ForEach(data.days) { day in
                DayProgressCard(day: day, colorScheme: colorScheme)
            }

            Spacer(minLength: 40)
        }
        .padding()
    }

    private func weekSummaryCard(_ summary: WeeklySummary) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Avg Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(summary.avgCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppGradients.primary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Compliance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(summary.complianceRate * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(summary.complianceRate >= 0.7 ? .green : .orange)
                }
            }

            HStack {
                StatPill(label: "Meals", value: "\(summary.totalMeals)")
                StatPill(label: "Days", value: "\(summary.daysTracked)")
            }
        }
        .padding()
        .glassMorphism()
    }

    // MARK: - Month Content

    private func monthContent(_ data: MonthlyProgressResponse) -> some View {
        VStack(spacing: 20) {
            // Summary card
            monthSummaryCard(data.summary)

            // Weekly breakdown
            sectionHeader(title: "Weekly Summaries", icon: "calendar.badge.clock")

            if data.weeks.isEmpty {
                Text("No weekly data yet. Keep tracking!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassMorphism()
            } else {
                ForEach(data.weeks) { week in
                    WeekSummaryCard(week: week, colorScheme: colorScheme)
                }
            }

            Spacer(minLength: 40)
        }
        .padding()
    }

    private func monthSummaryCard(_ summary: MonthlySummary) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Avg Compliance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(summary.avgComplianceRate * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppGradients.primary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Trend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: summary.trend == "improving" ? "arrow.up.right" :
                            summary.trend == "declining" ? "arrow.down.right" : "arrow.right")
                    Text(summary.trend.capitalized)
                }
                .font(.headline)
                .foregroundColor(summary.trend == "improving" ? .green :
                                    summary.trend == "declining" ? .red : .secondary)
            }
        }
        .padding()
        .glassMorphism()
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppGradients.primary)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary(for: colorScheme))
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        needsSetup = false

        do {
            switch selectedTab {
            case .today:
                todayData = try await apiService.fetchTodayProgress()
            case .week:
                weekData = try await apiService.fetchWeekProgress()
            case .month:
                monthData = try await apiService.fetchMonthlyProgress()
            }
        } catch let error as APIError {
            switch error {
            case .serverError(let message):
                if message.contains("not set up") || message.contains("not found") {
                    needsSetup = true
                } else {
                    errorMessage = message
                }
            default:
                errorMessage = "Failed to load progress"
            }
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }
}

// MARK: - Helper Views

struct MacroProgressBar: View {
    let label: String
    let current: Int
    let goal: Int
    let unit: String
    let color: Color

    var percentage: Double {
        goal > 0 ? min(Double(current) / Double(goal), 1.0) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(current)\(unit) / \(goal)\(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(current > goal ? Color.red : color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct RemainingCard: View {
    let label: String
    let value: Int
    let unit: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)\(unit)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(value < 0 ? .red : AppColors.textPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassMorphism()
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DayProgressCard: View {
    let day: DailyProgress
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(day.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(for: colorScheme))

                Text("\(day.mealCount) meals • \(day.totalCalories) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(day.isOnTrack ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("\(Int(day.complianceScore * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(day.isOnTrack ? .green : .orange)
                )
        }
        .padding()
        .glassMorphism()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

struct WeekSummaryCard: View {
    let week: WeeklySummary
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Week of \(formatDate(week.weekStart))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(for: colorScheme))

                Text("\(week.totalMeals) meals • Avg \(Int(week.avgCalories)) cal/day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(week.complianceRate >= 0.8 ? Color.green.opacity(0.2) :
                        week.complianceRate >= 0.6 ? Color.yellow.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("\(Int(week.complianceRate * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(week.complianceRate >= 0.8 ? .green :
                                            week.complianceRate >= 0.6 ? .yellow : .red)
                )
        }
        .padding()
        .glassMorphism()
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#endif
