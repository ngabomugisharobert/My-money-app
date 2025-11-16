//
//  ReportViewModel.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine

struct CategorySpending {
    let category: Category
    let amount: Double
    let percentage: Double
}

struct MonthlyData {
    let month: Date
    let income: Double
    let expenses: Double
}

class ReportViewModel: ObservableObject {
    @Published var categorySpending: [CategorySpending] = []
    @Published var monthlyData: [MonthlyData] = []
    @Published var selectedMonth: Date = Date()
    @Published var rangeIncome: Double = 0.0
    @Published var rangeExpenses: Double = 0.0
    
    private let context: NSManagedObjectContext
    private let transactionViewModel: TransactionViewModel
    private var userId: String?
    private var dateRange: (start: Date, end: Date)?
    
    init(context: NSManagedObjectContext, transactionViewModel: TransactionViewModel, userId: String? = nil) {
        self.context = context
        self.transactionViewModel = transactionViewModel
        self.userId = userId
        generateReports()
    }
    
    func setUserId(_ userId: String?) {
        self.userId = userId
        generateReports()
    }
    
    func generateReports() {
        generateCategorySpending()
        generateMonthlyData()
    }
    
    private func generateCategorySpending() {
        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date
        
        // Use date range if available, otherwise use selected month
        if let range = dateRange {
            startDate = range.start
            // Include the entire end date (end of day)
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
        } else {
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        }
        
        // Fetch expenses for the selected period
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        var predicates: [NSPredicate] = [
            NSPredicate(format: "type == %@", TransactionType.expense.rawValue),
            NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        ]
        
        // Filter by userId if available
        if let userId = userId {
            predicates.append(NSPredicate(format: "userId == %@", userId))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Optimize Core Data fetch
        request.fetchBatchSize = 50
        request.returnsObjectsAsFaults = false
        
        do {
            let expenses = try context.fetch(request)
            let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
        
            var categoryMap: [UUID: Double] = [:]
            
            for expense in expenses {
                if let category = expense.category {
                    let categoryId = category.id
                    categoryMap[categoryId, default: 0] += expense.amount
                }
            }
            
            var spending: [CategorySpending] = []
            let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
            
            let allCategories = try context.fetch(categoryRequest)
            
            for (categoryId, amount) in categoryMap {
                if let category = allCategories.first(where: { $0.id == categoryId }) {
                    let percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0
                    spending.append(CategorySpending(category: category, amount: amount, percentage: percentage))
                }
            }
            
            categorySpending = spending.sorted { $0.amount > $1.amount }
        } catch {
            print("Error generating category spending: \(error.localizedDescription)")
        }
    }
    
    private func generateMonthlyData() {
        let calendar = Calendar.current
        let now = Date()
        var months: [MonthlyData] = []
        
        // Get last 6 months
        for i in 0..<6 {
            guard let month = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            // Fetch transactions for this month directly
            let request = NSFetchRequest<Transaction>(entityName: "Transaction")
            var predicates: [NSPredicate] = [
                NSPredicate(format: "date >= %@ AND date < %@", startOfMonth as NSDate, endOfMonth as NSDate)
            ]
            
            // Filter by userId if available
            if let userId = userId {
                predicates.append(NSPredicate(format: "userId == %@", userId))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            // Optimize Core Data fetch
            request.fetchBatchSize = 50
            request.returnsObjectsAsFaults = false
            
            do {
                let transactions = try context.fetch(request)
                let income = transactions.filter { $0.transactionType == .income }.reduce(0) { $0 + $1.amount }
                let expenses = transactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + $1.amount }
                
                months.append(MonthlyData(month: startOfMonth, income: income, expenses: expenses))
            } catch {
                print("Error fetching monthly data: \(error.localizedDescription)")
            }
        }
        
        monthlyData = months.reversed()
    }
    
    func updateSelectedMonth(_ month: Date) {
        selectedMonth = month
        dateRange = nil // Clear date range when using month mode
        generateCategorySpending()
        generateRangeSummary()
    }
    
    func updateDateRange(startDate: Date, endDate: Date) {
        dateRange = (start: startDate, end: endDate)
        generateCategorySpending()
        generateRangeSummary()
    }
    
    private func generateRangeSummary() {
        guard let range = dateRange else {
            rangeIncome = 0.0
            rangeExpenses = 0.0
            return
        }
        
        let calendar = Calendar.current
        let startDate = range.start
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
        
        let request = NSFetchRequest<Transaction>(entityName: "Transaction")
        var predicates: [NSPredicate] = [
            NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        ]
        
        if let userId = userId {
            predicates.append(NSPredicate(format: "userId == %@", userId))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Optimize Core Data fetch - use properties to fetch only what we need
        request.fetchBatchSize = 100
        request.returnsObjectsAsFaults = false
        request.propertiesToFetch = ["amount", "type"] // Only fetch needed properties
        
        do {
            let transactions = try context.fetch(request)
            rangeIncome = transactions.filter { $0.transactionType == .income }.reduce(0) { $0 + $1.amount }
            rangeExpenses = transactions.filter { $0.transactionType == .expense }.reduce(0) { $0 + $1.amount }
        } catch {
            print("Error generating range summary: \(error.localizedDescription)")
            rangeIncome = 0.0
            rangeExpenses = 0.0
        }
    }
    
    // Data for pie chart
    func getPieChartData() -> [(category: Category, amount: Double, color: Color)] {
        return categorySpending.map { spending in
            (category: spending.category, amount: spending.amount, color: spending.category.colorValue)
        }
    }
    
    // Data for bar chart
    func getBarChartData() -> [(month: String, income: Double, expenses: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        return monthlyData.map { data in
            (month: formatter.string(from: data.month), income: data.income, expenses: data.expenses)
        }
    }
}

