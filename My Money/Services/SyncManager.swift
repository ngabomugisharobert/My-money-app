//
//  SyncManager.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import Combine
import CoreData

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let firestoreService = FirestoreService.shared
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Sync Transactions
    func syncTransactions(userId: String) {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        // Firestore automatically handles offline writes
        // This method can be used for manual sync if needed
        Task {
            // Firestore's offline persistence handles this automatically
            // But we can add custom sync logic here if needed
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
    }
    
    // MARK: - Sync Categories
    func syncCategories(userId: String) {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        Task {
            // Firestore handles offline writes automatically
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
    }
    
    // MARK: - Sync Verification and Full Sync
    func verifyAndSyncFromFirestore(userId: String) async throws {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
                self.lastSyncDate = Date()
            }
        }
        
        let firestoreService = FirestoreService.shared
        
        // Fetch all data from Firestore
        let firestoreTransactions = try await firestoreService.fetchAllTransactions(userId: userId)
        let firestoreCategories = try await firestoreService.fetchAllCategories(userId: userId)
        
        // Get local data counts
        let localTransactionCount = getLocalTransactionCount(userId: userId)
        let localCategoryCount = getLocalCategoryCount(userId: userId)
        
        // Compare counts
        let transactionCountMatches = firestoreTransactions.count == localTransactionCount
        let categoryCountMatches = firestoreCategories.count == localCategoryCount
        
        // If counts don't match, perform full sync from Firestore
        if !transactionCountMatches || !categoryCountMatches {
            print("Data mismatch detected. Syncing from Firestore...")
            print("Firestore: \(firestoreTransactions.count) transactions, \(firestoreCategories.count) categories")
            print("Local: \(localTransactionCount) transactions, \(localCategoryCount) categories")
            
            // Clear local user data and sync from Firestore
            await clearAndSyncFromFirestore(
                transactions: firestoreTransactions,
                categories: firestoreCategories,
                userId: userId
            )
        } else {
            // Even if counts match, verify individual records
            let needsSync = await verifyIndividualRecords(
                firestoreTransactions: firestoreTransactions,
                firestoreCategories: firestoreCategories,
                userId: userId
            )
            
            if needsSync {
                print("Individual record mismatch detected. Syncing from Firestore...")
                await clearAndSyncFromFirestore(
                    transactions: firestoreTransactions,
                    categories: firestoreCategories,
                    userId: userId
                )
            } else {
                print("Data is in sync. No action needed.")
            }
        }
    }
    
    private func getLocalTransactionCount(userId: String) -> Int {
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting local transactions: \(error)")
            return 0
        }
    }
    
    private func getLocalCategoryCount(userId: String) -> Int {
        let request = NSFetchRequest<Category>(entityName: "Category")
        request.predicate = NSPredicate(format: "isDefault == YES OR userId == %@", userId)
        
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting local categories: \(error)")
            return 0
        }
    }
    
    private func verifyIndividualRecords(
        firestoreTransactions: [TransactionData],
        firestoreCategories: [CategoryData],
        userId: String
    ) async -> Bool {
        // Check if all Firestore transaction IDs exist locally
        for transactionData in firestoreTransactions {
            guard let idString = transactionData.id,
                  let id = UUID(uuidString: idString) else { continue }
            
            let request = NSFetchRequest<Transaction>(entityName: "Transaction")
            request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id as CVarArg, userId)
            
            do {
                let count = try context.count(for: request)
                if count == 0 {
                    return true // Missing transaction found
                }
            } catch {
                return true // Error checking, assume needs sync
            }
        }
        
        // Check if all Firestore category IDs exist locally
        for categoryData in firestoreCategories {
            guard let idString = categoryData.id,
                  let id = UUID(uuidString: idString) else { continue }
            
            let request = NSFetchRequest<Category>(entityName: "Category")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let count = try context.count(for: request)
                if count == 0 {
                    return true // Missing category found
                }
            } catch {
                return true // Error checking, assume needs sync
            }
        }
        
        return false // All records exist
    }
    
    private func clearAndSyncFromFirestore(
        transactions: [TransactionData],
        categories: [CategoryData],
        userId: String
    ) async {
        // Delete user's local transactions
        let transactionRequest = NSFetchRequest<Transaction>(entityName: "Transaction")
        transactionRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let localTransactions = try context.fetch(transactionRequest)
            for transaction in localTransactions {
                context.delete(transaction)
            }
        } catch {
            print("Error deleting local transactions: \(error)")
        }
        
        // Delete user's custom categories (keep defaults)
        let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
        categoryRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let localCategories = try context.fetch(categoryRequest)
            for category in localCategories {
                context.delete(category)
            }
        } catch {
            print("Error deleting local categories: \(error)")
        }
        
        // Save deletions
        do {
            try context.save()
        } catch {
            print("Error saving after deletions: \(error)")
        }
        
        // Sync all data from Firestore
        for transactionData in transactions {
            syncTransactionToCoreData(transactionData, userId: userId, context: context)
        }
        
        for categoryData in categories {
            syncCategoryToCoreData(categoryData, userId: userId, context: context)
        }
        
        // Final save
        do {
            try context.save()
            print("Successfully synced \(transactions.count) transactions and \(categories.count) categories from Firestore")
        } catch {
            print("Error saving synced data: \(error)")
            await MainActor.run {
                self.syncError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Convert Core Data to Firestore Models
    func transactionToFirestore(_ transaction: Transaction) -> TransactionData? {
        // Create TransactionData WITHOUT setting @DocumentID property
        // The ID will be used only for the document path, not in the data structure
        return TransactionData(
            id: nil, // Don't set @DocumentID - Firestore manages it
            amount: transaction.amount,
            type: transaction.type,
            categoryId: transaction.category?.id.uuidString,
            categoryName: transaction.category?.name,
            date: transaction.date,
            note: transaction.note
        )
    }
    
    func categoryToFirestore(_ category: Category) -> CategoryData? {
        // Create CategoryData WITHOUT setting @DocumentID property
        // The ID will be used only for the document path, not in the data structure
        return CategoryData(
            id: nil, // Don't set @DocumentID - Firestore manages it
            name: category.name,
            icon: category.icon,
            color: category.color,
            type: category.type,
            isDefault: category.isDefault
        )
    }
    
    // Helper methods to get document IDs for path construction
    func getTransactionDocumentId(_ transaction: Transaction) -> String {
        return transaction.id.uuidString
    }
    
    func getCategoryDocumentId(_ category: Category) -> String {
        return category.id.uuidString
    }
    
    // MARK: - Convert Firestore to Core Data
    func syncTransactionToCoreData(_ data: TransactionData, userId: String, context: NSManagedObjectContext) {
        // Convert String ID to UUID for Core Data
        guard let idString = data.id,
              let id = UUID(uuidString: idString) else { return }
        
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        request.predicate = NSPredicate(format: "id == %@ AND userId == %@", id as CVarArg, userId)
        
        do {
            let existing = try context.fetch(request).first
            
            if let existing = existing {
                // Update existing
                existing.amount = data.amount
                existing.type = data.type
                existing.date = data.date
                existing.note = data.note
                existing.userId = userId
                
                if let categoryIdString = data.categoryId,
                   let categoryId = UUID(uuidString: categoryIdString) {
                    let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
                    categoryRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
                    if let category = try context.fetch(categoryRequest).first {
                        existing.category = category
                    }
                }
            } else {
                // Create new
                let transaction = Transaction(context: context)
                transaction.id = id
                transaction.userId = userId
                transaction.amount = data.amount
                transaction.type = data.type
                transaction.date = data.date
                transaction.note = data.note
                
                if let categoryIdString = data.categoryId,
                   let categoryId = UUID(uuidString: categoryIdString) {
                    let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
                    categoryRequest.predicate = NSPredicate(format: "id == %@", categoryId as CVarArg)
                    if let category = try context.fetch(categoryRequest).first {
                        transaction.category = category
                    }
                }
            }
            
            try context.save()
        } catch {
            print("Error syncing transaction to Core Data: \(error)")
        }
    }
    
    func syncCategoryToCoreData(_ data: CategoryData, userId: String, context: NSManagedObjectContext) {
        // Convert String ID to UUID for Core Data
        guard let idString = data.id,
              let id = UUID(uuidString: idString) else { return }
        
        let request = NSFetchRequest<Category>(entityName: "Category")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let existing = try context.fetch(request).first
            
            if let existing = existing {
                // Update existing
                existing.name = data.name
                existing.icon = data.icon
                existing.color = data.color
                existing.type = data.type
                existing.isDefault = data.isDefault
                // Only set userId for custom categories
                if !data.isDefault {
                    existing.userId = userId
                }
            } else {
                // Create new
                let category = Category(context: context)
                category.id = id
                category.name = data.name
                category.icon = data.icon
                category.color = data.color
                category.type = data.type
                category.isDefault = data.isDefault
                // Only set userId for custom categories
                if !data.isDefault {
                    category.userId = userId
                }
            }
            
            try context.save()
        } catch {
            print("Error syncing category to Core Data: \(error)")
        }
    }
}

