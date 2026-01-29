import Foundation
import CoreData
#if canImport(UIKit)
import UIKit
#endif

public class StorageService {
    public static let shared: StorageService = {
        do {
            return try StorageService()
        } catch {
            fatalError("Failed to initialize StorageService: \(error)")
        }
    }()
    
    private let persistentContainer: NSPersistentContainer
    private let maxEntries = 100
    
    private init() throws {
        // Build the Core Data model programmatically first
        let model = StorageService.buildModel()
        
        // Initialize the container with the explicit managed object model
        persistentContainer = NSPersistentContainer(name: "NutritionAI", managedObjectModel: model)
        
        // Use an in-memory store for now (ephemeral during app runs)
        let description = NSPersistentStoreDescription()
        // Use a SQLite store for persistent storage across app launches
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("NutritionAI.sqlite")
        description.url = storeURL
        description.type = NSSQLiteStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        var setupError: Error?
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                setupError = error
            }
        }
        
        if let error = setupError {
            throw error
        }
    }
    
    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "StoredMealAnalysis"
        entity.managedObjectClassName = NSStringFromClass(StoredMealAnalysis.self)
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = true
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = true
        
        let thumbnailDataAttribute = NSAttributeDescription()
        thumbnailDataAttribute.name = "thumbnailData"
        thumbnailDataAttribute.attributeType = .binaryDataAttributeType
        thumbnailDataAttribute.isOptional = true
        
        let nutritionDataAttribute = NSAttributeDescription()
        nutritionDataAttribute.name = "nutritionData"
        nutritionDataAttribute.attributeType = .binaryDataAttributeType
        nutritionDataAttribute.isOptional = true
        
        let foodsDataAttribute = NSAttributeDescription()
        foodsDataAttribute.name = "foodsData"
        foodsDataAttribute.attributeType = .binaryDataAttributeType
        foodsDataAttribute.isOptional = true
        
        let backendIdAttribute = NSAttributeDescription()
        backendIdAttribute.name = "backendId"
        backendIdAttribute.attributeType = .stringAttributeType
        backendIdAttribute.isOptional = true
        
        entity.properties = [
            idAttribute,
            timestampAttribute,
            thumbnailDataAttribute,
            nutritionDataAttribute,
            foodsDataAttribute,
            backendIdAttribute
        ]
        model.entities = [entity]
        return model
    }
    
    @MainActor
    public func save(analysis: MealAnalysis, thumbnail: Data?) throws {
        let context = persistentContainer.viewContext
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let nutritionData = try encoder.encode(analysis.totals)
        let foodsData = try encoder.encode(analysis.foods)
        
        let stored = StoredMealAnalysis(context: context)
        stored.id = UUID()
        stored.timestamp = analysis.timestamp
        stored.thumbnailData = thumbnail
        stored.nutritionData = nutritionData
        stored.foodsData = foodsData
        
        try context.save()
        
        // Auto-prune to keep maximum 100 entries
        try pruneOldEntries()
    }
    
    /// Save a meal from cloud data with base64 thumbnail
    @MainActor
    public func saveFromCloud(cloudMeal: CloudMeal) throws {
        let context = persistentContainer.viewContext
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Convert CloudFood to FoodItem
        let foods = cloudMeal.foods.map { cf in
            FoodItem(
                name: cf.name,
                portion: cf.portion,
                nutrition: NutritionData(
                    calories: cf.nutrition.calories,
                    protein: cf.nutrition.protein,
                    carbs: cf.nutrition.carbs,
                    fat: cf.nutrition.fat
                ),
                confidence: cf.confidence
            )
        }
        
        let totals = NutritionData(
            calories: cloudMeal.totals.calories,
            protein: cloudMeal.totals.protein,
            carbs: cloudMeal.totals.carbs,
            fat: cloudMeal.totals.fat
        )
        
        let nutritionData = try encoder.encode(totals)
        let foodsData = try encoder.encode(foods)
        
        // Decode base64 thumbnail if present
        var thumbnailData: Data? = nil
        if let base64String = cloudMeal.thumbnail {
            // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
            let base64Data: String
            if let commaIndex = base64String.firstIndex(of: ",") {
                base64Data = String(base64String[base64String.index(after: commaIndex)...])
            } else {
                base64Data = base64String
            }
            thumbnailData = Data(base64Encoded: base64Data)
        }
        
        let stored = StoredMealAnalysis(context: context)
        stored.id = UUID(uuidString: cloudMeal.id) ?? UUID()
        stored.backendId = cloudMeal.id  // Store the backend ID for sync operations
        stored.timestamp = cloudMeal.timestamp
        stored.thumbnailData = thumbnailData
        stored.nutritionData = nutritionData
        stored.foodsData = foodsData
        
        try context.save()
    }
    
    /// Clear all stored meals (for sync reset)
    @MainActor
    public func clearAllMeals() throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        let results = try context.fetch(request)
        for meal in results {
            context.delete(meal)
        }
        try context.save()
    }
    
    /// Check how many meals are stored locally
    @MainActor
    public func mealCount() throws -> Int {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        return try context.count(for: request)
    }
    
    @MainActor
    public func fetchHistory() throws -> [MealAnalysis] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let results = try context.fetch(request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try results.map { item in
            guard let nutritionData = item.nutritionData,
                  let foodsData = item.foodsData,
                  let timestamp = item.timestamp else {
                throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid stored data"])
            }
            
            let totals = try decoder.decode(NutritionData.self, from: nutritionData)
            let foods = try decoder.decode([FoodItem].self, from: foodsData)
            return MealAnalysis(backendId: item.backendId, foods: foods, totals: totals, timestamp: timestamp)
        }
    }
    
    @MainActor
    public func fetchHistoryWithThumbnails() throws -> [(analysis: MealAnalysis, thumbnail: UIImage?)] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let results = try context.fetch(request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try results.map { item in
            guard let nutritionData = item.nutritionData,
                  let foodsData = item.foodsData,
                  let timestamp = item.timestamp else {
                throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid stored data"])
            }
            
            let totals = try decoder.decode(NutritionData.self, from: nutritionData)
            let foods = try decoder.decode([FoodItem].self, from: foodsData)
            let analysis = MealAnalysis(backendId: item.backendId, foods: foods, totals: totals, timestamp: timestamp)
            
            let thumbnail: UIImage? = if let thumbnailData = item.thumbnailData {
                UIImage(data: thumbnailData)
            } else {
                nil
            }
            
            return (analysis: analysis, thumbnail: thumbnail)
        }
    }
    
    @MainActor
    public func fetchRecentHistory(limit: Int = 10) throws -> [MealAnalysis] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        let results = try context.fetch(request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try results.map { item in
            guard let nutritionData = item.nutritionData,
                  let foodsData = item.foodsData,
                  let timestamp = item.timestamp else {
                throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid stored data"])
            }
            
            let totals = try decoder.decode(NutritionData.self, from: nutritionData)
            let foods = try decoder.decode([FoodItem].self, from: foodsData)
            return MealAnalysis(backendId: item.backendId, foods: foods, totals: totals, timestamp: timestamp)
        }
    }
    
    @MainActor
    private func pruneOldEntries() throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let allEntries = try context.fetch(request)
        
        if allEntries.count > maxEntries {
            let entriesToDelete = Array(allEntries.dropFirst(maxEntries))
            for entry in entriesToDelete {
                context.delete(entry)
            }
            try context.save()
        }
    }
    
    /// Delete a meal by its timestamp (used as unique identifier)
    @MainActor
    public func deleteMeal(byTimestamp timestamp: Date) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.predicate = NSPredicate(format: "timestamp == %@", timestamp as NSDate)
        
        let results = try context.fetch(request)
        guard let mealToDelete = results.first else {
            throw NSError(domain: "StorageService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Meal not found"])
        }
        
        context.delete(mealToDelete)
        try context.save()
        print("[StorageService] Deleted meal with timestamp: \(timestamp)")
    }
    
    /// Update a meal's data
    @MainActor
    public func updateMeal(originalTimestamp: Date, updatedAnalysis: MealAnalysis, thumbnail: Data?) throws {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.predicate = NSPredicate(format: "timestamp == %@", originalTimestamp as NSDate)
        
        let results = try context.fetch(request)
        guard let mealToUpdate = results.first else {
            throw NSError(domain: "StorageService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Meal not found"])
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let nutritionData = try encoder.encode(updatedAnalysis.totals)
        let foodsData = try encoder.encode(updatedAnalysis.foods)
        
        mealToUpdate.timestamp = updatedAnalysis.timestamp
        mealToUpdate.nutritionData = nutritionData
        mealToUpdate.foodsData = foodsData
        if let thumbnail = thumbnail {
            mealToUpdate.thumbnailData = thumbnail
        }
        
        try context.save()
        print("[StorageService] Updated meal with timestamp: \(originalTimestamp) -> \(updatedAnalysis.timestamp)")
    }
    
    /// Get the thumbnail data for a meal
    @MainActor
    public func getThumbnailData(forTimestamp timestamp: Date) throws -> Data? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StoredMealAnalysis>(entityName: "StoredMealAnalysis")
        request.predicate = NSPredicate(format: "timestamp == %@", timestamp as NSDate)
        
        let results = try context.fetch(request)
        return results.first?.thumbnailData
    }
}

@objc(StoredMealAnalysis)
class StoredMealAnalysis: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var backendId: String?
    @NSManaged var timestamp: Date?
    @NSManaged var thumbnailData: Data?
    @NSManaged var nutritionData: Data?
    @NSManaged var foodsData: Data?
}
