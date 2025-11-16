//
//  CategoryViewModel.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine
import FirebaseFirestore

class CategoryViewModel: ObservableObject {
    @Published var categories: [Category] = []
    
    let context: NSManagedObjectContext
    
    // Firestore listener (stored property must be in main class, not extension)
    // Using internal access so extension in separate file can access it
    var firestoreListener: ListenerRegistration?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        // Don't fetch on init - let views control when to fetch
    }
    
    deinit {
        removeFirestoreListener()
    }
    
    func fetchCategories(userId: String? = nil, type: TransactionType? = nil) {
        // Ensure Core Data operations happen on the context's queue
        // For view context, this should be the main thread
        context.perform {
            let request = NSFetchRequest<Category>(entityName: "Category")
            var predicates: [NSPredicate] = []
            
            // Show default categories (userId == nil) OR user's custom categories
            if let userId = userId {
                predicates.append(NSPredicate(format: "isDefault == YES OR userId == %@", userId))
            } else {
                // If no userId, only show defaults
                predicates.append(NSPredicate(format: "isDefault == YES"))
            }
            
            if let type = type {
                predicates.append(NSPredicate(format: "type == %@", type.rawValue))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Category.isDefault, ascending: false),
                NSSortDescriptor(keyPath: \Category.name, ascending: true)
            ]
            
            // Optimize Core Data fetch
            request.fetchBatchSize = 20
            request.returnsObjectsAsFaults = false
            
            do {
                let fetchedCategories = try self.context.fetch(request)
                
                // Update @Published properties on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.categories = fetchedCategories
                }
            } catch {
                print("Error fetching categories: \(error.localizedDescription)")
            }
        }
    }
    
    func addCustomCategory(userId: String, name: String, icon: String, color: String, type: TransactionType) {
        // Perform Core Data operations on the context's queue
        context.perform {
            let category = Category(context: self.context)
            category.id = UUID()
            category.userId = userId
            category.name = name
            category.icon = icon
            category.color = color
            category.type = type.rawValue
            category.isDefault = false
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh all objects unnecessarily - fetchCategories will get fresh data
                
                // Fetch updated categories on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.fetchCategories(userId: userId)
                }
            } catch {
                print("Error saving category: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
    }
    
    func deleteCategory(_ category: Category) {
        // Don't allow deletion of default categories
        guard !category.isDefault else { return }
        
        // Ensure we're on the context's queue
        context.perform {
            // Check if object is still valid before deleting
            guard !category.isDeleted && category.managedObjectContext != nil else {
                print("Warning: Category is already deleted or has no context")
                return
            }
            
            self.context.delete(category)
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh all objects unnecessarily - fetchCategories will get fresh data
                
                // Fetch updated categories on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.fetchCategories()
                }
            } catch {
                print("Error deleting category: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
    }
    
    func getCategories(for type: TransactionType) -> [Category] {
        return categories.filter { $0.type == type.rawValue }
    }
}

