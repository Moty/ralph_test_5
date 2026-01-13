//
//  NutritionResultView.swift
//  NutritionAIApp
//

import SwiftUI
import NutritionAI

struct NutritionResultView: View {
    let image: UIImage
    @State private var mealAnalysis: MealAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Captured food image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    if isLoading {
                        // Loading indicator
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Analyzing your food...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if let error = errorMessage {
                        // Error message
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Analysis Failed")
                                .font(.headline)
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                analyzeImage()
                            }) {
                                Text("Retry")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 40)
                    } else if let analysis = mealAnalysis {
                        // Nutrition results
                        VStack(spacing: 16) {
                            // Summary card
                            NutritionSummaryCard(nutrition: analysis.totals)
                                .padding(.horizontal)
                            
                            // Individual food items
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Detected Foods")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                ForEach(Array(analysis.foods.enumerated()), id: \.offset) { _, food in
                                    FoodItemCard(foodItem: food)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Nutrition Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            analyzeImage()
        }
    }
    
    private func analyzeImage() {
        isLoading = true
        errorMessage = nil
        mealAnalysis = nil
        
        Task {
            do {
                let analysis = try await APIService.shared.analyzeImage(image)
                await MainActor.run {
                    self.mealAnalysis = analysis
                    self.isLoading = false
                    
                    // Save to storage
                    saveToStorage(analysis: analysis)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    if let apiError = error as? APIError {
                        self.errorMessage = apiError.localizedDescription
                    } else {
                        self.errorMessage = "An unexpected error occurred"
                    }
                }
            }
        }
    }
    
    private func saveToStorage(analysis: MealAnalysis) {
        // Save asynchronously without blocking UI
        Task {
            do {
                // Create thumbnail from image
                let thumbnailData = image.jpegData(compressionQuality: 0.5)
                
                try StorageService.shared.save(analysis: analysis, thumbnail: thumbnailData)
            } catch {
                // Log error but don't block user
                print("Failed to save analysis to storage: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    NutritionResultView(image: UIImage(systemName: "photo")!)
}
