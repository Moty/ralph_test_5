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
        description.type = NSInMemoryStoreType
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
        
        entity.properties = [
            idAttribute,
            timestampAttribute,
            thumbnailDataAttribute,
            nutritionDataAttribute,
            foodsDataAttribute
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
            return MealAnalysis(foods: foods, totals: totals, timestamp: timestamp)
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
            return MealAnalysis(foods: foods, totals: totals, timestamp: timestamp)
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
}

@objc(StoredMealAnalysis)
class StoredMealAnalysis: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var timestamp: Date?
    @NSManaged var thumbnailData: Data?
    @NSManaged var nutritionData: Data?
    @NSManaged var foodsData: Data?
}
