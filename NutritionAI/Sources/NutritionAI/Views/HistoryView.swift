import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HistoryView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject var syncService = SyncService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var historyItems: [HistoryItem] = []
    @State private var error: String?
    @State private var selectedMeal: MealAnalysis?
    @State private var isLoading: Bool = false
    private let storageService = StorageService.shared
    
    struct HistoryItem: Identifiable {
        let id: Date
        let analysis: MealAnalysis
        let thumbnail: UIImage?
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                AppGradients.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Syncing meals...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    } else if historyItems.isEmpty && error == nil {
                        emptyStateView
                    } else if let error = error {
                        errorView(message: error)
                    } else {
                        historyListView
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !syncService.isSyncing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { Task { await syncAndReload() } }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(AppGradients.primary)
                        }
                    }
                }
            }
            .onAppear {
                loadHistoryAndSyncIfNeeded()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppGradients.primary.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "tray")
                    .font(.system(size: 50))
                    .foregroundStyle(AppGradients.primary)
            }
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start analyzing meals to see them here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Example")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SampleHistoryCard()
            }

            Text("Tip: Capture a meal from the Camera tab")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .glassMorphism()
        .padding()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 45))
                    .foregroundColor(.orange)
            }
            
            Text("Error Loading History")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .glassMorphism()
        .padding()
    }
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(Array(historyItems.enumerated()), id: \.element.id) { index, item in
                    HistoryItemCard(analysis: item.analysis, thumbnail: item.thumbnail, index: index)
                        .onTapGesture {
                            selectedMeal = item.analysis
                        }
                }
            }
            .padding()
        }
        .sheet(item: $selectedMeal) { meal in
            NavigationView {
                NutritionDetailView(mealAnalysis: meal)
                    .navigationTitle("Meal Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                selectedMeal = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
            }
        }
    }
    
    private func loadHistory() {
        do {
            let items = try storageService.fetchHistoryWithThumbnails()
            historyItems = items.map { item in
                HistoryItem(
                    id: item.analysis.timestamp,
                    analysis: item.analysis,
                    thumbnail: item.thumbnail
                )
            }
        } catch {
            self.error = "Failed to load meal history"
        }
    }
    
    private func loadHistoryAndSyncIfNeeded() {
        // First load any local data
        loadHistory()
        
        // If authenticated and no local history, try to sync from cloud
        if authService.isAuthenticated && historyItems.isEmpty {
            Task {
                await syncAndReload()
            }
        }
    }
    
    private func syncAndReload() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await syncService.syncFromCloud()
            loadHistory()
        } catch {
            print("[HistoryView] Sync failed: \(error.localizedDescription)")
            // Don't show error - just keep what we have locally
        }
    }
}

struct NutritionDetailView: View {
    let mealAnalysis: MealAnalysis
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            AppGradients.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Total nutrition summary
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "chart.pie.fill")
                                .foregroundStyle(AppGradients.primary)
                            Text("Total Nutrition")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        HStack(spacing: 14) {
                            NutritionSummaryCard(
                                label: "Calories",
                                value: String(format: "%.0f", mealAnalysis.totals.calories),
                                unit: "kcal",
                                color: AppColors.calories,
                                icon: "flame.fill"
                            )
                            
                            NutritionSummaryCard(
                                label: "Protein",
                                value: String(format: "%.1f", mealAnalysis.totals.protein),
                                unit: "g",
                                color: AppColors.protein,
                                icon: "bolt.fill"
                            )
                        }
                        
                        HStack(spacing: 14) {
                            NutritionSummaryCard(
                                label: "Carbs",
                                value: String(format: "%.1f", mealAnalysis.totals.carbs),
                                unit: "g",
                                color: AppColors.carbs,
                                icon: "leaf.fill"
                            )
                            
                            NutritionSummaryCard(
                                label: "Fat",
                                value: String(format: "%.1f", mealAnalysis.totals.fat),
                                unit: "g",
                                color: AppColors.fat,
                                icon: "drop.fill"
                            )
                        }
                    }
                    .padding(20)
                    .glassMorphism(cornerRadius: 20)
                    
                    // Individual food items
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundStyle(AppGradients.primary)
                            Text("Food Items")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        ForEach(Array(mealAnalysis.foods.enumerated()), id: \.offset) { index, food in
                            FoodItemCard(food: food, index: index)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct HistoryItemCard: View {
    let analysis: MealAnalysis
    let thumbnail: UIImage?
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail or gradient placeholder
            Group {
                if let thumbnail = thumbnail {
                    #if canImport(UIKit)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    ZStack {
                        AppGradients.cardGradient(at: index)
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int(analysis.totals.calories))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("cal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(formatDate(analysis.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label("\(analysis.foods.count) items", systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.primaryGradientStart)
                    
                    Label(String(format: "%.0fg protein", analysis.totals.protein), systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.protein)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right.circle.fill")
                .font(.title3)
                .foregroundStyle(AppGradients.primary)
        }
        .padding(16)
        .glassMorphism(cornerRadius: 18)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SampleHistoryCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                AppGradients.cardGradient(at: 0)
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("520")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("cal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Sample meal • Today 12:30 PM")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Label("3 items", systemImage: "leaf.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.primaryGradientStart)

                    Label("32g protein", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.protein)
                }
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
                .font(.title3)
                .foregroundStyle(AppGradients.primary)
        }
        .padding(16)
        .glassMorphism(cornerRadius: 18)
    }
}
