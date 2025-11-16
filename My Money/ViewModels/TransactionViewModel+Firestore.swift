//
//  TransactionViewModel+Firestore.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import Combine
import FirebaseFirestore

extension TransactionViewModel {
    // MARK: - Firestore Integration
    
    func setupFirestoreListener(userId: String) {
        // Remove existing listener if any
        removeFirestoreListener()
        
        let firestoreService = FirestoreService.shared
        let syncManager = SyncManager(context: context)
        
        // Store the listener registration to keep it active
        firestoreListener = firestoreService.listenToTransactions(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transactions):
                // Sync Firestore data to Core Data
                for transactionData in transactions {
                    syncManager.syncTransactionToCoreData(transactionData, userId: userId, context: self.context)
                }
                
                // Refresh local data
                DispatchQueue.main.async {
                    self.fetchTransactions(userId: userId)
                }
                
            case .failure(let error):
                print("Error listening to transactions: \(error.localizedDescription)")
            }
        }
    }
    
    func removeFirestoreListener() {
        firestoreListener?.remove()
        firestoreListener = nil
    }
    
    func addTransactionWithSync(amount: Double, type: TransactionType, category: Category, date: Date, note: String? = nil, userId: String?) async {
        guard let userId = userId else { return }
        
        let categoryID = category.objectID
        
        // Use the base addTransaction method which handles Core Data properly
        // We need to create the transaction first to get a reference for Firestore sync
        var transaction: Transaction?
        
        // Perform Core Data operations on the context's queue
        // For view contexts, perform executes synchronously on main thread
        await context.perform {
            let newTransaction = Transaction(context: self.context)
            newTransaction.id = UUID()
            newTransaction.userId = userId
            newTransaction.amount = amount
            newTransaction.transactionType = type
            if let category = try? self.context.existingObject(with: categoryID) as? Category {
                newTransaction.category = category
            } else {
                print("Failed to fetch category from context")
                return
            }
            newTransaction.date = date
            newTransaction.note = note
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh all objects unnecessarily - fetchTransactions will get fresh data
                transaction = newTransaction
            } catch {
                print("Error saving transaction: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
        
        // Force UI update on main thread
        await MainActor.run {
            // Trigger a refresh by fetching with current filters
            // The view will observe the @Published transactions property
            self.fetchTransactions(userId: userId)
        }
        
        // Sync to Firestore if transaction was created successfully
        if let transaction = transaction {
            let firestoreService = FirestoreService.shared
            let syncManager = SyncManager(context: context)
            
            if let transactionData = syncManager.transactionToFirestore(transaction) {
                let documentId = syncManager.getTransactionDocumentId(transaction)
                do {
                    try await firestoreService.addTransaction(userId: userId, transaction: transactionData, documentId: documentId)
                } catch {
                    print("Error syncing transaction to Firestore: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateTransactionWithSync(_ transaction: Transaction, amount: Double, type: TransactionType, category: Category, date: Date, note: String? = nil, userId: String?) async {
        // Update in Core Data first
        updateTransaction(transaction, amount: amount, type: type, category: category, date: date, note: note, userId: userId)
        
        // Force UI refresh on main thread after Core Data update
        await MainActor.run {
            // Trigger objectWillChange to notify SwiftUI of the update
            self.objectWillChange.send()
            // Post notification for views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("TransactionUpdated"), object: nil)
        }
        
        // Sync to Firestore if user is authenticated
        if let userId = userId {
            let firestoreService = FirestoreService.shared
            let syncManager = SyncManager(context: context)
            
            if let transactionData = syncManager.transactionToFirestore(transaction) {
                let documentId = syncManager.getTransactionDocumentId(transaction)
                do {
                    try await firestoreService.updateTransaction(userId: userId, transaction: transactionData, documentId: documentId)
                } catch {
                    print("Error syncing transaction update to Firestore: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func deleteTransactionWithSync(_ transaction: Transaction, userId: String?) async {
        let transactionId = transaction.id
        
        // Delete from Core Data first
        deleteTransaction(transaction)
        
        // Force UI refresh on main thread after deletion
        await MainActor.run {
            // Trigger objectWillChange to notify SwiftUI of the update
            self.objectWillChange.send()
            // Post notification for views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("TransactionUpdated"), object: nil)
        }
        
        // Delete from Firestore if user is authenticated
        if let userId = userId {
            let firestoreService = FirestoreService.shared
            do {
                // Convert UUID to String for Firestore
                try await firestoreService.deleteTransaction(userId: userId, transactionId: transactionId.uuidString)
            } catch {
                print("Error deleting transaction from Firestore: \(error.localizedDescription)")
            }
        }
    }
}

