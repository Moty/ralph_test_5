import SwiftUI

struct FilteredMealsView: View {
    let title: String
    let filterType: MealFilterType
    @State private var meals: [(analysis: MealAnalysis, thumbnail: UIImage?)] = []
    @State private var selectedMeal: MealAnalysis?
    
    private let storageService = StorageService.shared
    
    enum MealFilterType {
        case today
        case thisWeek
        case all
    }
    
    var body: some View {
        ZStack {
            AppGradients.background
                .ignoresSafeArea()
            
            ScrollView {
                if meals.isEmpty {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(AppGradients.primary.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundStyle(AppGradients.primary)
                        }
                        
                        Text("No meals found")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Start tracking by capturing your meals")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .glassMorphism()
                    .padding()
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(meals.enumerated()), id: \.offset) { index, item in
                            HistoryItemCard(
                                analysis: item.analysis,
                                thumbnail: item.thumbnail,
                                index: index
                            )
                            .onTapGesture {
                                selectedMeal = item.analysis
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMeals()
        }
        .sheet(item: $selectedMeal) { meal in
            NutritionDetailView(mealAnalysis: meal)
        }
    }
    
    private func loadMeals() {
        do {
            let allMeals = try storageService.fetchHistoryWithThumbnails()
            
            switch filterType {
            case .today:
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                meals = allMeals.filter { calendar.isDate($0.analysis.timestamp, inSameDayAs: today) }
                
            case .thisWeek:
                let calendar = Calendar.current
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                meals = allMeals.filter { $0.analysis.timestamp >= weekAgo }
                
            case .all:
                meals = allMeals
            }
        } catch {
            print("Error loading meals: \(error)")
        }
    }
}

// Extension to make MealAnalysis conform to Identifiable
extension MealAnalysis: Identifiable {
    public var id: String {
        "\(timestamp.timeIntervalSince1970)"
    }
}
