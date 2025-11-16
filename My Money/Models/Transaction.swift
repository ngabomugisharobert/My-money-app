//
//  Transaction.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData

@objc(Transaction)
public class Transaction: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var amount: Double
    @NSManaged public var type: String
    @NSManaged public var date: Date
    @NSManaged public var note: String?
    @NSManaged public var userId: String
    @NSManaged public var category: Category?
}

extension Transaction {
    var transactionType: TransactionType {
        get {
            TransactionType(rawValue: type) ?? .expense
        }
        set {
            type = newValue.rawValue
        }
    }
    
    var categoryName: String {
        category?.name ?? "Uncategorized"
    }
}

enum TransactionType: String, CaseIterable {
    case income = "income"
    case expense = "expense"
    
    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }
    
    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        }
    }
}

