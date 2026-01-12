import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HistoryView: View {
    @State private var meals: [MealAnalysis] = []
    @State private var error: String?
    @State private var selectedMeal: MealAnalysis?
    private let storageService = StorageService.shared
    
    var body: some View {
        NavigationView {
            Group {
                if meals.isEmpty && error == nil {
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
                .foregroundColor(.gray)
            Text("No Meal History")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Analyzed meals will appear here")
                .font(.body)
                .foregroundColor(.secondary)
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
            LazyVStack(spacing: 16) {
                ForEach(Array(meals.enumerated()), id: \.offset) { index, meal in
                    HistoryItemCard(meal: meal)
                        .onTapGesture {
                            selectedMeal = meal
                        }
                }
            }
            .padding()
        }
        .sheet(item: Binding(
            get: { selectedMeal },
            set: { selectedMeal = $0 }
        )) { meal in
            NavigationView {
                NutritionResultView(analysis: meal)
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Done") {
                                selectedMeal = nil
                            }
                        }
                    }
            }
        }
    }
    
    private func loadHistory() {
        do {
            meals = try storageService.fetchHistory()
        } catch {
            self.error = "Failed to load meal history"
        }
    }
}

struct HistoryItemCard: View {
    let meal: MealAnalysis
    
    var body: some View {
        HStack(spacing: 16) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(meal.totals.calories)) cal")
                    .font(.headline)
                Text(formatDate(meal.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(meal.foods.count) item\(meal.foods.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
