import Foundation
import CoreData
#if canImport(UIKit)
import UIKit
#endif

class StorageService {
    private let persistentContainer: NSPersistentContainer
    private let maxEntries = 100
    
    init() throws {
        persistentContainer = NSPersistentContainer(name: "NutritionAI")
        persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        
        var setupError: Error?
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                setupError = error
            }
        }
        
        if let error = setupError {
            throw error
        }
        
        try setupModel()
    }
    
    private func setupModel() throws {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "StoredMealAnalysis"
        entity.managedObjectClassName = NSStringFromClass(StoredMealAnalysis.self)
        
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        
        let thumbnailDataAttribute = NSAttributeDescription()
        thumbnailDataAttribute.name = "thumbnailData"
        thumbnailDataAttribute.attributeType = .binaryDataAttributeType
        thumbnailDataAttribute.isOptional = true
        
        let nutritionDataAttribute = NSAttributeDescription()
        nutritionDataAttribute.name = "nutritionData"
        nutritionDataAttribute.attributeType = .binaryDataAttributeType
        
        let foodsDataAttribute = NSAttributeDescription()
        foodsDataAttribute.name = "foodsData"
        foodsDataAttribute.attributeType = .binaryDataAttributeType
        
        entity.properties = [idAttribute, timestampAttribute, thumbnailDataAttribute, nutritionDataAttribute, foodsDataAttribute]
        model.entities = [entity]
    }
    
    @MainActor
    func save(analysis: MealAnalysis, thumbnail: Data?) throws {
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
    func fetchHistory() throws -> [MealAnalysis] {
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
    func fetchRecentHistory(limit: Int = 10) throws -> [MealAnalysis] {
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
