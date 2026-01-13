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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back,")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(authService.currentUser?.name ?? "User")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Stats Section
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Text("Failed to load stats")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                loadStats()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if let stats = stats {
                        statsSection(stats)
                    } else {
                        emptyStateView
                    }
                    
                    // Quick Capture Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Capture")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            QuickCaptureTile(
                                icon: "camera.fill",
                                label: "Full Meal"
                            ) {
                                selectedTab = 1 // Navigate to Camera tab
                            }
                            
                            QuickCaptureTile(
                                icon: "fork.knife",
                                label: "Snack"
                            ) {
                                selectedTab = 1 // Navigate to Camera tab
                            }
                            
                            QuickCaptureTile(
                                icon: "plus.circle.fill",
                                label: "Quick Add"
                            ) {
                                selectedTab = 1 // Navigate to Camera tab
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No meals logged yet")
                .font(.headline)
            Text("Start tracking by capturing your first meal below")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func statsSection(_ stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today Stats
            Text("Today")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatsCard(
                    title: "Meals",
                    value: "\(stats.today.count)",
                    subtitle: nil
                )
                .onTapGesture {
                    showingFilteredMeals = .today
                }
                
                StatsCard(
                    title: "Calories",
                    value: "\(stats.today.totalCalories)",
                    subtitle: "kcal"
                )
                .onTapGesture {
                    showingFilteredMeals = .today
                }
            }
            .padding(.horizontal)
            
            // This Week Stats
            Text("This Week")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatsCard(
                    title: "Meals",
                    value: "\(stats.week.count)",
                    subtitle: nil
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Avg Calories",
                    value: "\(stats.week.avgCalories)",
                    subtitle: "kcal/meal"
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Total Calories",
                    value: "\(stats.week.totalCalories)",
                    subtitle: "kcal"
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
                
                StatsCard(
                    title: "Protein",
                    value: "\(stats.week.totalProtein)g",
                    subtitle: nil
                )
                .onTapGesture {
                    showingFilteredMeals = .thisWeek
                }
            }
            .padding(.horizontal)
            
            // All Time Stats
            Text("All Time")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatsCard(
                    title: "Total Meals",
                    value: "\(stats.allTime.count)",
                    subtitle: nil
                )
                
                StatsCard(
                    title: "Avg Calories",
                    value: "\(stats.allTime.avgCalories)",
                    subtitle: "kcal/meal"
                )
            }
            .padding(.horizontal)
        }
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
