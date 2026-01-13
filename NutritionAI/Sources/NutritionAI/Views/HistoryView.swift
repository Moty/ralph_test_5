import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HistoryView: View {
    @State private var historyItems: [HistoryItem] = []
    @State private var error: String?
    @State private var selectedMeal: MealAnalysis?
    private let storageService = StorageService.shared
    
    struct HistoryItem: Identifiable {
        let id: Date
        let analysis: MealAnalysis
        let thumbnail: UIImage?
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Group {
                if historyItems.isEmpty && error == nil {
                    emptyStateView
                } else if let error = error {
                    errorView(message: error)
                } else {
                    historyListView
                }
            }
            .navigationTitle("History")
            .onAppear {
                loadHistory()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Start analyzing meals to see them here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Error Loading History")
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(historyItems) { item in
                    HistoryItemCard(analysis: item.analysis, thumbnail: item.thumbnail)
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
}

struct NutritionDetailView: View {
    let mealAnalysis: MealAnalysis
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Total nutrition summary
                VStack(spacing: 12) {
                    Text("Total Nutrition")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 20) {
                        NutritionSummaryCard(
                            label: "Calories",
                            value: String(format: "%.0f", mealAnalysis.totals.calories),
                            unit: "kcal"
                        )
                        
                        NutritionSummaryCard(
                            label: "Protein",
                            value: String(format: "%.1f", mealAnalysis.totals.protein),
                            unit: "g"
                        )
                    }
                    
                    HStack(spacing: 20) {
                        NutritionSummaryCard(
                            label: "Carbs",
                            value: String(format: "%.1f", mealAnalysis.totals.carbs),
                            unit: "g"
                        )
                        
                        NutritionSummaryCard(
                            label: "Fat",
                            value: String(format: "%.1f", mealAnalysis.totals.fat),
                            unit: "g"
                        )
                    }
                }
                .padding()
                #if canImport(UIKit)
                .background(Color(.secondarySystemBackground))
                #else
                .background(Color.gray.opacity(0.1))
                #endif
                .cornerRadius(12)
                
                // Individual food items
                VStack(alignment: .leading, spacing: 16) {
                    Text("Food Items")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(mealAnalysis.foods.enumerated()), id: \.offset) { index, food in
                        FoodItemCard(food: food)
                    }
                }
            }
            .padding()
        }
    }
}

struct HistoryItemCard: View {
    let analysis: MealAnalysis
    let thumbnail: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            Group {
                if let thumbnail = thumbnail {
                    #if canImport(UIKit)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 60, height: 60)
            #if canImport(UIKit)
            .background(Color(.tertiarySystemBackground))
            #else
            .background(Color.gray.opacity(0.2))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(analysis.totals.calories)) cal")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(formatDate(analysis.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(analysis.foods.count) item\(analysis.foods.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Make MealAnalysis Identifiable for sheet presentation
extension MealAnalysis: Identifiable {
    public var id: Date { timestamp }
}
