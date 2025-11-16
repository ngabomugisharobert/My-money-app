//
//  TransactionViewModel.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine
import FirebaseFirestore

class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var totalIncome: Double = 0.0
    @Published var totalExpenses: Double = 0.0
    @Published var balance: Double = 0.0
    
    let context: NSManagedObjectContext
    
    // Batch size for pagination
    private let batchSize = 50
    private var currentOffset = 0
    
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
    
    func fetchTransactions(userId: String? = nil, filterBy type: TransactionType? = nil, 
                          category: Category? = nil,
                          month: Date? = nil,
                          dateRange: (start: Date, end: Date)? = nil,
                          limit: Int? = nil) {
        // Ensure Core Data operations happen on the context's queue
        // For view context, this should be the main thread
        context.perform {
            let request = NSFetchRequest<Transaction>(entityName: "Transaction")
            var predicates: [NSPredicate] = []
            
            // Always filter by userId if provided
            if let userId = userId {
                predicates.append(NSPredicate(format: "userId == %@", userId))
            }
            
            if let type = type {
                predicates.append(NSPredicate(format: "type == %@", type.rawValue))
            }
            
            if let category = category {
                predicates.append(NSPredicate(format: "category == %@", category))
            }
            
            if let month = month {
                let calendar = Calendar.current
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
                predicates.append(NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate))
            }
            
            if let dateRange = dateRange {
                predicates.append(NSPredicate(format: "date >= %@ AND date <= %@", dateRange.start as NSDate, dateRange.end as NSDate))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            
            // Optimize Core Data fetch with batch size and faulting
            request.fetchBatchSize = limit ?? self.batchSize
            request.returnsObjectsAsFaults = false // Pre-fetch relationships
            
            // Set limit if provided
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            do {
                let fetchedTransactions = try self.context.fetch(request)
                
                // Update @Published properties on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.transactions = fetchedTransactions
                    self.calculateTotals()
                }
            } catch {
                print("Error fetching transactions: \(error.localizedDescription)")
            }
        }
    }
    
    func addTransaction(userId: String, amount: Double, type: TransactionType, category: Category, date: Date, note: String? = nil) {
        // Perform Core Data operations on the context's queue
        context.perform {
            let transaction = Transaction(context: self.context)
            transaction.id = UUID()
            transaction.userId = userId
            transaction.amount = amount
            transaction.transactionType = type
            transaction.category = category
            transaction.date = date
            transaction.note = note
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh all objects unnecessarily - fetchTransactions will get fresh data
                
                // Fetch updated transactions on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.fetchTransactions(userId: userId)
                }
            } catch {
                print("Error saving transaction: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
    }
    
    // Store current filter state for refresh after updates
    private var currentUserId: String?
    private var currentFilterType: TransactionType?
    private var currentMonth: Date?
    
    func updateTransaction(_ transaction: Transaction, amount: Double, type: TransactionType, category: Category, date: Date, note: String? = nil, userId: String? = nil) {
        // Ensure we're on the context's queue
        context.perform {
            // Check if object is still valid before updating
            guard !transaction.isDeleted && transaction.managedObjectContext != nil else {
                print("Warning: Transaction is deleted or has no context")
                return
            }
            
            // Update transaction properties
            transaction.amount = amount
            transaction.transactionType = type
            transaction.category = category
            transaction.date = date
            transaction.note = note
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh individual objects - let Core Data manage state automatically
                // The fetchTransactions call below will refresh the list with current data
            } catch {
                print("Error updating transaction: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
        
        // Refresh with stored filters if available, otherwise use provided userId
        // This is done outside context.perform to avoid nested async issues
        if let userId = userId {
            // Refresh with userId and stored filters to maintain view state
            refreshWithCurrentFilters(userId: userId)
        } else if let userId = currentUserId {
            refreshWithCurrentFilters(userId: userId)
        } else {
            // Fallback: refresh without filters (for backward compatibility)
            fetchTransactions()
        }
    }
    
    private func refreshWithCurrentFilters(userId: String) {
        // Refresh with stored filter state to maintain what the view is showing
        fetchTransactions(
            userId: userId,
            filterBy: currentFilterType,
            month: currentMonth
        )
    }
    
    // Call this when fetching to store current filter state
    func setCurrentFilters(userId: String?, type: TransactionType?, month: Date?) {
        self.currentUserId = userId
        self.currentFilterType = type
        self.currentMonth = month
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        // Ensure we're on the context's queue
        context.perform {
            // Check if object is still valid before deleting
            guard !transaction.isDeleted && transaction.managedObjectContext != nil else {
                print("Warning: Transaction is already deleted or has no context")
                return
            }
            
            self.context.delete(transaction)
            
            // Save context - Core Data will automatically handle object state
            do {
                try self.context.save()
                // Don't refresh all objects unnecessarily - fetchTransactions will get fresh data
                
                // Refresh with stored filters if available
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if let userId = self.currentUserId {
                        self.refreshWithCurrentFilters(userId: userId)
                    } else {
                        self.fetchTransactions()
                    }
                }
            } catch {
                print("Error deleting transaction: \(error.localizedDescription)")
                // If save fails, try to rollback
                self.context.rollback()
            }
        }
    }
    
    private func calculateTotals() {
        // Ensure calculations happen on main thread since @Published properties are updated
        // This method is already called from main thread via DispatchQueue.main.async
        totalIncome = transactions
            .filter { $0.transactionType == .income }
            .reduce(0) { $0 + $1.amount }
        
        totalExpenses = transactions
            .filter { $0.transactionType == .expense }
            .reduce(0) { $0 + $1.amount }
        
        balance = totalIncome - totalExpenses
    }
    
    func getTransactionsForMonth(_ date: Date) -> [Transaction] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return transactions.filter { transaction in
            let transactionDate = transaction.date
            return transactionDate >= startOfMonth && transactionDate < endOfMonth
        }
    }
}

