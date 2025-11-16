//
//  CoreDataManager.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        // Load the model file
        guard let modelURL = Bundle.main.url(forResource: "My_Money", withExtension: "momd"),
              let originalModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }
        
        // Create a new mutable model with the same entities but explicit class names
        let mutableModel = NSManagedObjectModel()
        mutableModel.entities = originalModel.entities.map { originalEntity in
            let entity = originalEntity.copy() as! NSEntityDescription
            // Set explicit class names to avoid "Failed to find a unique match" errors
            if entity.name == "Transaction" {
                entity.managedObjectClassName = NSStringFromClass(Transaction.self)
            } else if entity.name == "Category" {
                entity.managedObjectClassName = NSStringFromClass(Category.self)
            }
            return entity
        }
        
        // Note: configurations and versionIdentifiers are read-only properties
        // They are automatically handled by Core Data based on the model file
        
        // Create persistent container with the configured model
        persistentContainer = NSPersistentContainer(name: "My_Money", managedObjectModel: mutableModel)
        
        // Configure persistent store description
        let description = persistentContainer.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        
        // Optimize Core Data context
        let viewContext = persistentContainer.viewContext
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.undoManager = nil // Disable undo manager to save memory
        viewContext.shouldDeleteInaccessibleFaults = true // Auto-delete inaccessible faults
    }
    
    func save() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
            }
        }
    }
    
    // Initialize default categories
    func initializeDefaultCategories() {
        let context = viewContext
        let request = NSFetchRequest<Category>(entityName: "Category")
        
        do {
            let existingCategories = try context.fetch(request)
            if !existingCategories.isEmpty {
                return // Categories already initialized
            }
            
            // Add expense categories
            for defaultCat in DefaultCategory.expenseCategories {
                let category = Category(context: context)
                category.id = UUID()
                category.name = defaultCat.name
                category.icon = defaultCat.icon
                category.color = defaultCat.color
                category.type = defaultCat.type.rawValue
                category.isDefault = true
            }
            
            // Add income categories
            for defaultCat in DefaultCategory.incomeCategories {
                let category = Category(context: context)
                category.id = UUID()
                category.name = defaultCat.name
                category.icon = defaultCat.icon
                category.color = defaultCat.color
                category.type = defaultCat.type.rawValue
                category.isDefault = true
            }
            
            save()
        } catch {
            print("Error initializing categories: \(error.localizedDescription)")
        }
    }
    
    // Clear user-specific data on logout
    func clearUserData(userId: String) {
        let context = viewContext
        
        // Delete user's transactions
        let transactionRequest = NSFetchRequest<Transaction>(entityName: "Transaction")
        transactionRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let transactions = try context.fetch(transactionRequest)
            for transaction in transactions {
                context.delete(transaction)
            }
        } catch {
            print("Error deleting user transactions: \(error.localizedDescription)")
        }
        
        // Delete user's custom categories (not defaults)
        let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
        categoryRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let categories = try context.fetch(categoryRequest)
            for category in categories {
                context.delete(category)
            }
        } catch {
            print("Error deleting user categories: \(error.localizedDescription)")
        }
        
        save()
    }
}

