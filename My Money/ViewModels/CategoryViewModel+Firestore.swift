//
//  CategoryViewModel+Firestore.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import Combine
import FirebaseFirestore

extension CategoryViewModel {
    // MARK: - Firestore Integration
    
    func setupFirestoreListener(userId: String) {
        // Remove existing listener if any
        removeFirestoreListener()
        
        let firestoreService = FirestoreService.shared
        let syncManager = SyncManager(context: context)
        
        // Store the listener registration to keep it active
        firestoreListener = firestoreService.listenToCategories(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let categories):
                // Sync Firestore data to Core Data
                for categoryData in categories {
                    syncManager.syncCategoryToCoreData(categoryData, userId: userId, context: self.context)
                }
                
                // Refresh local data
                DispatchQueue.main.async {
                    self.fetchCategories(userId: userId)
                }
                
            case .failure(let error):
                print("Error listening to categories: \(error.localizedDescription)")
            }
        }
    }
    
    func removeFirestoreListener() {
        firestoreListener?.remove()
        firestoreListener = nil
    }
    
    func addCustomCategoryWithSync(name: String, icon: String, color: String, type: TransactionType, userId: String?) async {
        guard let userId = userId else { return }
        
        // Create category in Core Data first
        let category = Category(context: context)
        category.id = UUID()
        category.userId = userId
        category.name = name
        category.icon = icon
        category.color = color
        category.type = type.rawValue
        category.isDefault = false
        
        CoreDataManager.shared.save()
        fetchCategories(userId: userId)
        
        // Sync to Firestore
        let firestoreService = FirestoreService.shared
        let syncManager = SyncManager(context: context)
        
        if let categoryData = syncManager.categoryToFirestore(category) {
            let documentId = syncManager.getCategoryDocumentId(category)
            do {
                try await firestoreService.addCategory(userId: userId, category: categoryData, documentId: documentId)
            } catch {
                print("Error syncing category to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteCategoryWithSync(_ category: Category, userId: String?) async {
        let categoryId = category.id
        
        // Delete from Core Data first
        deleteCategory(category)
        
        // Delete from Firestore if user is authenticated
        if let userId = userId {
            let firestoreService = FirestoreService.shared
            do {
                // Convert UUID to String for Firestore
                try await firestoreService.deleteCategory(userId: userId, categoryId: categoryId.uuidString)
            } catch {
                print("Error deleting category from Firestore: \(error.localizedDescription)")
            }
        }
    }
}

