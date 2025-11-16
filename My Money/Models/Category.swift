//
//  Category.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import SwiftUI

@objc(Category)
public class Category: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var icon: String?
    @NSManaged public var color: String?
    @NSManaged public var type: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var userId: String?
    @NSManaged public var transactions: NSSet?
}

extension Category {
    var colorValue: Color {
        Color(hex: color ?? "#000000")
    }
    
    var iconName: String {
        icon ?? "folder"
    }
    
    // Convenience accessor for transactions relationship
    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: Transaction)
    
    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: Transaction)
    
    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)
    
    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)
}

// Default categories data
struct DefaultCategory {
    let name: String
    let icon: String
    let color: String
    let type: TransactionType
    
    static let expenseCategories: [DefaultCategory] = [
        DefaultCategory(name: "Food", icon: "fork.knife", color: "#FF6B6B", type: .expense),
        DefaultCategory(name: "Transport", icon: "car.fill", color: "#4ECDC4", type: .expense),
        DefaultCategory(name: "Shopping", icon: "bag.fill", color: "#95E1D3", type: .expense),
        DefaultCategory(name: "Bills", icon: "doc.text.fill", color: "#F38181", type: .expense),
        DefaultCategory(name: "Entertainment", icon: "tv.fill", color: "#AA96DA", type: .expense),
        DefaultCategory(name: "Health", icon: "heart.fill", color: "#FCBAD3", type: .expense),
        DefaultCategory(name: "Education", icon: "book.fill", color: "#A8E6CF", type: .expense),
        DefaultCategory(name: "Other", icon: "ellipsis.circle.fill", color: "#D3D3D3", type: .expense)
    ]
    
    static let incomeCategories: [DefaultCategory] = [
        DefaultCategory(name: "Salary", icon: "dollarsign.circle.fill", color: "#51CF66", type: .income),
        DefaultCategory(name: "Freelance", icon: "briefcase.fill", color: "#339AF0", type: .income),
        DefaultCategory(name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#845EF7", type: .income),
        DefaultCategory(name: "Gift", icon: "gift.fill", color: "#FFD43B", type: .income),
        DefaultCategory(name: "Other", icon: "ellipsis.circle.fill", color: "#D3D3D3", type: .income)
    ]
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

