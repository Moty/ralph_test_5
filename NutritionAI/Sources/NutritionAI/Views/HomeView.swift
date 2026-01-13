import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var stats: UserStats?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFilteredMeals: FilteredMealsView.MealFilterType?
    @Binding var selectedTab: Int
    
    let apiService: APIService
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated background
                AnimatedBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Welcome Header with gradient
                        welcomeHeader
                        
                        // Stats Section
                        if isLoading {
                            loadingView
                        } else if let error = errorMessage {
                            errorStateView(error)
                        } else if let stats = stats {
                            statsSection(stats)
                        } else {
                            emptyStateView
                        }
                        
                        // Quick Capture Section
                        quickCaptureSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NutritionAI")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .refreshable {
                loadStats()
            }
            .sheet(item: Binding(
                get: { showingFilteredMeals.map { FilteredMealsIdentifiable(type: $0) } },
                set: { showingFilteredMeals = $0?.type }
            )) { item in
                NavigationView {
                    FilteredMealsView(
                        title: item.title,
                        filterType: item.type
                    )
                }
            }
        }
        .onAppear {
            if stats == nil {
                loadStats()
            }
        }
    }
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack {
                Text(authService.currentUser?.name ?? "User")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppGradients.welcomeHeader)
                
                Text("👋")
                    .font(.title)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your stats...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassMorphism()
        .padding(.horizontal)
    }
    
    private func errorStateView(_ error: String) -> some View {
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
            
            Text("Failed to load stats")
                .font(.headline)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: loadStats) {
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppGradients.primary.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(AppGradients.primary)
            }
            
            Text("No meals logged yet")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Start tracking by capturing your first meal below")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .glassMorphism()
        .padding(.horizontal)
    }
    
    private var quickCaptureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(AppGradients.primary)
                Text("Quick Capture")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                QuickCaptureTile(
                    icon: "camera.fill",
                    label: "Full Meal",
                    gradientIndex: 0
                ) {
                    selectedTab = 1
                }
                
                QuickCaptureTile(
                    icon: "fork.knife",
                    label: "Snack",
                    gradientIndex: 1
                ) {
                    selectedTab = 1
                }
                
                QuickCaptureTile(
                    icon: "plus.circle.fill",
                    label: "Quick Add",
                    gradientIndex: 2
                ) {
                    selectedTab = 1
                }
                
                QuickCaptureTile(
                    icon: "clock.arrow.circlepath",
                    label: "Recent",
                    gradientIndex: 3
                ) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func statsSection(_ stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Today Stats
            sectionHeader(title: "Today", icon: "sun.max.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                StatsCard(
                    title: "Meals",
                    value: "\(stats.today.count)",
                    subtitle: nil,
                    icon: "fork.knife",
                    gradientIndex: 0
                )
                .onTapGesture {
                    showingFilteredMeals = .today
                }
                
                StatsCard(
                    title: "Calories",
                    value: "\(stats.today.totalCalories)",
                    subtitle: "kcal",
                    icon: "flame.fill",
                    gradientIndex: 1
                )
                .onTapGesture {
                    showingFilteredMeals = .today
                }
            }
            .padding(.horizontal)
            
            // This Week Stats
            sectionHeader(title: "This Week", icon: "calendar")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                StatsCard(
                    title: "Meals",
                    value: "\(stats.week.count)",
                    subtitle: nil,
                    icon: "fork.knife",
                    gradientIndex: 2
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Avg Calories",
                    value: "\(stats.week.avgCalories)",
                    subtitle: "kcal/meal",
                    icon: "chart.line.uptrend.xyaxis",
                    gradientIndex: 3
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Total Calories",
                    value: "\(stats.week.totalCalories)",
                    subtitle: "kcal",
                    icon: "flame.fill",
                    gradientIndex: 0
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Protein",
                    value: "\(stats.week.totalProtein)g",
                    subtitle: nil,
                    icon: "bolt.fill",
                    gradientIndex: 1
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
            }
            .padding(.horizontal)
            
            // All Time Stats
            sectionHeader(title: "All Time", icon: "star.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                StatsCard(
                    title: "Total Meals",
                    value: "\(stats.allTime.count)",
                    subtitle: nil,
                    icon: "tray.full.fill",
                    gradientIndex: 2
                )
                
                StatsCard(
                    title: "Avg Calories",
                    value: "\(stats.allTime.avgCalories)",
                    subtitle: "kcal/meal",
                    icon: "chart.bar.fill",
                    gradientIndex: 3
                )
            }
            .padding(.horizontal)
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppGradients.primary)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(.horizontal)
    }
    
    private func loadStats() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                let fetchedStats = try await apiService.fetchUserStats()
                await MainActor.run {
                    stats = fetchedStats
                    isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .serverError(let message):
                        errorMessage = message
                    case .unauthorized:
                        errorMessage = "Please login again"
                    case .noInternetConnection:
                        errorMessage = "No internet connection"
                    default:
                        errorMessage = "Failed to load stats"
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

struct FilteredMealsIdentifiable: Identifiable {
    let type: FilteredMealsView.MealFilterType
    var id: String {
        switch type {
        case .today: return "today"
        case .thisWeek: return "thisWeek"
        case .all: return "all"
        }
    }
    
    var title: String {
        switch type {
        case .today: return "Today's Meals"
        case .thisWeek: return "This Week's Meals"
        case .all: return "All Meals"
        }
    }
}
