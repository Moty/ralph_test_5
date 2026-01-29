import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// View for editing a meal entry
struct MealEditView: View {
    let originalMeal: MealAnalysis
    let originalThumbnail: UIImage?
    let onSave: (MealAnalysis) -> Void
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    // Editable fields
    @State private var mealDate: Date
    @State private var editableFoods: [EditableFood]
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    struct EditableFood: Identifiable {
        let id = UUID()
        var name: String
        var portion: String
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var confidence: Double?
    }
    
    init(meal: MealAnalysis, thumbnail: UIImage?, onSave: @escaping (MealAnalysis) -> Void, onCancel: @escaping () -> Void) {
        self.originalMeal = meal
        self.originalThumbnail = thumbnail
        self.onSave = onSave
        self.onCancel = onCancel
        
        _mealDate = State(initialValue: meal.timestamp)
        _editableFoods = State(initialValue: meal.foods.map { food in
            EditableFood(
                name: food.name,
                portion: food.portion,
                calories: food.nutrition.calories,
                protein: food.nutrition.protein,
                carbs: food.nutrition.carbs,
                fat: food.nutrition.fat,
                confidence: food.confidence
            )
        })
    }
    
    private var totalCalories: Double {
        editableFoods.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        editableFoods.reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        editableFoods.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        editableFoods.reduce(0) { $0 + $1.fat }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppGradients.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Thumbnail preview
                        if let thumbnail = originalThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                        }
                        
                        // Date picker section
                        dateSection
                        
                        // Totals summary (calculated from foods)
                        totalsSummarySection
                        
                        // Food items list
                        foodItemsSection
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(AppGradients.primary)
                Text("Date & Time")
                    .font(.headline)
            }
            
            DatePicker(
                "Meal Date",
                selection: $mealDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .padding()
            .glassMorphism(cornerRadius: 12)
        }
        .padding(.horizontal)
    }
    
    private var totalsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(AppGradients.primary)
                Text("Totals (Auto-calculated)")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                TotalCard(label: "Calories", value: String(format: "%.0f", totalCalories), unit: "kcal", color: AppColors.calories)
                TotalCard(label: "Protein", value: String(format: "%.1f", totalProtein), unit: "g", color: AppColors.protein)
            }
            HStack(spacing: 12) {
                TotalCard(label: "Carbs", value: String(format: "%.1f", totalCarbs), unit: "g", color: AppColors.carbs)
                TotalCard(label: "Fat", value: String(format: "%.1f", totalFat), unit: "g", color: AppColors.fat)
            }
        }
        .padding(.horizontal)
    }
    
    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundStyle(AppGradients.primary)
                Text("Food Items")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    addNewFood()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppGradients.primary)
                        .font(.title2)
                }
            }
            
            ForEach($editableFoods) { $food in
                EditableFoodCard(food: $food, onDelete: {
                    if let index = editableFoods.firstIndex(where: { $0.id == food.id }) {
                        editableFoods.remove(at: index)
                    }
                })
            }
        }
        .padding(.horizontal)
    }
    
    private func addNewFood() {
        let newFood = EditableFood(
            name: "New Item",
            portion: "1 serving",
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            confidence: 0.8
        )
        editableFoods.append(newFood)
    }
    
    private func saveChanges() {
        // Convert editable foods back to FoodItem array
        let updatedFoods = editableFoods.map { ef in
            FoodItem(
                name: ef.name,
                portion: ef.portion,
                nutrition: NutritionData(
                    calories: ef.calories,
                    protein: ef.protein,
                    carbs: ef.carbs,
                    fat: ef.fat
                ),
                confidence: ef.confidence ?? 0.8
            )
        }
        
        let updatedTotals = NutritionData(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat
        )
        
        let updatedMeal = MealAnalysis(
            foods: updatedFoods,
            totals: updatedTotals,
            timestamp: mealDate
        )
        
        onSave(updatedMeal)
    }
}

// MARK: - Supporting Views

private struct TotalCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .cornerRadius(12)
    }
}

private struct EditableFoodCard: View {
    @Binding var food: MealEditView.EditableFood
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Food name", text: $food.name)
                        .font(.headline)
                    TextField("Portion", text: $food.portion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(food.calories)) cal")
                        .font(.headline)
                        .foregroundColor(AppColors.calories)
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundStyle(AppGradients.primary)
                    }
                }
            }
            .padding()
            
            // Expandable section for nutrition editing
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        NutritionField(label: "Calories", value: $food.calories, unit: "kcal", color: AppColors.calories)
                        NutritionField(label: "Protein", value: $food.protein, unit: "g", color: AppColors.protein)
                    }
                    HStack(spacing: 12) {
                        NutritionField(label: "Carbs", value: $food.carbs, unit: "g", color: AppColors.carbs)
                        NutritionField(label: "Fat", value: $food.fat, unit: "g", color: AppColors.fat)
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Item")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .glassMorphism(cornerRadius: 16)
    }
}

private struct NutritionField: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct MealEditView_Previews: PreviewProvider {
    static var previews: some View {
        MealEditView(
            meal: MealAnalysis(
                foods: [
                    FoodItem(
                        name: "Grilled Chicken Breast",
                        portion: "6 oz",
                        nutrition: NutritionData(calories: 280, protein: 52, carbs: 0, fat: 6),
                        confidence: 0.9
                    ),
                    FoodItem(
                        name: "Brown Rice",
                        portion: "1 cup",
                        nutrition: NutritionData(calories: 216, protein: 5, carbs: 45, fat: 2),
                        confidence: 0.85
                    )
                ],
                totals: NutritionData(calories: 496, protein: 57, carbs: 45, fat: 8),
                timestamp: Date()
            ),
            thumbnail: nil,
            onSave: { _ in },
            onCancel: {}
        )
    }
}
#endif
