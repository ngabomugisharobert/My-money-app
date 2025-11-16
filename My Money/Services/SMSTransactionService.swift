//
//  SMSTransactionService.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import Combine
import MessageUI
import UserNotifications
import CoreData

class SMSTransactionService: NSObject, ObservableObject {
    @Published var isEnabled = false
    @Published var lastProcessedMessage: String?
    @Published var autoCreatedTransactions: [String] = []
    
    private let context: NSManagedObjectContext
    private var userId: String?
    
    // Common bank SMS patterns
    // Format: (pattern, amountIndex, merchantIndex, dateIndex, isIncome)
    private let transactionPatterns: [(pattern: String, amountIndex: Int, merchantIndex: Int, dateIndex: Int, isIncome: Bool)] = [
        // Chase Zelle income: "Chase | Zelle(R): PAUL WANGECHI sent you $49.95 & it's ready now."
        (pattern: #"Chase.*?Zelle.*?([A-Z][A-Z\s]+?)\s+sent\s+you\s+\$([\d,]+\.?\d*)"#, amountIndex: 2, merchantIndex: 1, dateIndex: -1, isIncome: true),
        // Generic Zelle pattern: "SENDER sent you $XX.XX"
        (pattern: #"([A-Z][A-Z\s]+?)\s+sent\s+you\s+\$([\d,]+\.?\d*)"#, amountIndex: 2, merchantIndex: 1, dateIndex: -1, isIncome: true),
        // Chase expense: "Chase Freedom Unlimited Visa: You made a $18.48 transaction with FRED-MEYER #0186 on Nov 13, 2025 at 8:26 PM ET."
        (pattern: #"Chase.*?\$([\d,]+\.?\d*).*?with\s+([A-Z0-9\s#-]+?)\s+(?:on|at)\s+([A-Za-z]+\s+\d+,\s+\d+)"#, amountIndex: 1, merchantIndex: 2, dateIndex: 3, isIncome: false),
        // Generic pattern: "$XX.XX at MERCHANT on DATE"
        (pattern: #"\$([\d,]+\.?\d*)\s+at\s+([A-Z0-9\s#-]+?)\s+on\s+([A-Za-z]+\s+\d+,\s+\d+)"#, amountIndex: 1, merchantIndex: 2, dateIndex: 3, isIncome: false),
        // Pattern: "You spent $XX.XX at MERCHANT"
        (pattern: #"spent\s+\$([\d,]+\.?\d*)\s+at\s+([A-Z0-9\s#-]+)"#, amountIndex: 1, merchantIndex: 2, dateIndex: -1, isIncome: false),
        // Pattern: "$XX.XX charged at MERCHANT"
        (pattern: #"\$([\d,]+\.?\d*)\s+charged\s+at\s+([A-Z0-9\s#-]+)"#, amountIndex: 1, merchantIndex: 2, dateIndex: -1, isIncome: false)
    ]
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        loadSettings()
    }
    
    func setUserId(_ userId: String?) {
        self.userId = userId
    }
    
    // MARK: - Settings
    private func loadSettings() {
        // Load from UserDefaults
        isEnabled = UserDefaults.standard.bool(forKey: "smsAutoTransactionEnabled")
        if let lastMessage = UserDefaults.standard.string(forKey: "lastProcessedSMS") {
            lastProcessedMessage = lastMessage
        }
    }
    
    func enableAutoTransactions(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "smsAutoTransactionEnabled")
        
        if enabled {
            requestNotificationPermission()
        }
    }
    
    // MARK: - SMS Processing
    func processSMS(_ messageBody: String) {
        guard isEnabled, let userId = userId else { return }
        
        // Skip if we've already processed this message
        if messageBody == lastProcessedMessage {
            return
        }
        
        // Try to extract transaction details
        if let transaction = parseTransactionFromSMSInternal(messageBody) {
            createTransactionFromSMS(transaction, userId: userId)
            lastProcessedMessage = messageBody
            UserDefaults.standard.set(messageBody, forKey: "lastProcessedSMS")
        }
    }
    
    // MARK: - Parsing (Public wrapper)
    func parseTransactionFromSMS(_ message: String) -> ParsedTransaction? {
        return parseTransactionFromSMSInternal(message)
    }
    
    private func parseTransactionFromSMSInternal(_ message: String) -> ParsedTransaction? {
        for patternInfo in transactionPatterns {
            if let regex = try? NSRegularExpression(pattern: patternInfo.pattern, options: [.caseInsensitive]) {
                let range = NSRange(message.startIndex..., in: message)
                if let match = regex.firstMatch(in: message, options: [], range: range) {
                    // Extract amount
                    if patternInfo.amountIndex > 0 && patternInfo.amountIndex <= match.numberOfRanges {
                        let amountRange = match.range(at: patternInfo.amountIndex)
                        if let swiftRange = Range(amountRange, in: message),
                           let amount = Double(message[swiftRange].replacingOccurrences(of: ",", with: "")) {
                            
                            // Extract merchant/sender
                            var merchant = "Unknown"
                            if patternInfo.merchantIndex > 0 && patternInfo.merchantIndex <= match.numberOfRanges {
                                let merchantRange = match.range(at: patternInfo.merchantIndex)
                                if let swiftRange = Range(merchantRange, in: message) {
                                    merchant = String(message[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            
                            // Extract date
                            var date = Date()
                            if patternInfo.dateIndex > 0 && patternInfo.dateIndex <= match.numberOfRanges {
                                let dateRange = match.range(at: patternInfo.dateIndex)
                                if let swiftRange = Range(dateRange, in: message) {
                                    let dateString = String(message[swiftRange])
                                    if let parsedDate = parseDate(from: dateString) {
                                        date = parsedDate
                                    }
                                }
                            }
                            
                            return ParsedTransaction(
                                amount: amount,
                                merchant: merchant,
                                date: date,
                                note: message,
                                isIncome: patternInfo.isIncome
                            )
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "MMM d, yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM d, yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMM dd, yyyy"
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - Public Methods
    func createTransactionFromParsed(_ parsed: ParsedTransaction, userId: String) {
        createTransactionFromSMS(parsed, userId: userId)
    }
    
    // MARK: - Transaction Creation
    private func createTransactionFromSMS(_ parsed: ParsedTransaction, userId: String) {
        // Determine transaction type
        let transactionType: TransactionType = parsed.isIncome ? .income : .expense
        
        // Create transaction
        Task { @MainActor in
            // Fetch category directly in the same context that will be used for the transaction
            let categoryRequest = NSFetchRequest<Category>(entityName: "Category")
            var predicates: [NSPredicate] = []
            
            // Show default categories (userId == nil) OR user's custom categories
            predicates.append(NSPredicate(format: "isDefault == YES OR userId == %@", userId))
            predicates.append(NSPredicate(format: "type == %@", transactionType.rawValue))
            
            categoryRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            categoryRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Category.isDefault, ascending: false),
                NSSortDescriptor(keyPath: \Category.name, ascending: true)
            ]
            
            // Fetch categories in the same context
            guard let categories = try? context.fetch(categoryRequest),
                  let category = categories.first(where: { $0.name == "Other" && $0.type == transactionType.rawValue })
                  ?? categories.first else {
                print("No \(transactionType == .income ? "income" : "expense") category found for auto-imported transaction")
                return
            }
            
            // Ensure the category is in the correct context
            guard category.managedObjectContext == context else {
                print("Category is not in the correct context")
                return
            }
            
            let transactionViewModel = TransactionViewModel(context: context)
            
            await transactionViewModel.addTransactionWithSync(
                amount: parsed.amount,
                type: transactionType,
                category: category,
                date: parsed.date,
                note: parsed.isIncome ? "Auto-imported from SMS: Received from \(parsed.merchant)" : "Auto-imported from SMS: \(parsed.merchant)",
                userId: userId
            )
            
            let prefix = parsed.isIncome ? "Received from" : ""
            autoCreatedTransactions.append("\(prefix) \(parsed.merchant): $\(String(format: "%.2f", parsed.amount))")
            
            // Show notification
            showNotification(amount: parsed.amount, merchant: parsed.merchant, isIncome: parsed.isIncome)
        }
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func showNotification(amount: Double, merchant: String, isIncome: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = "Transaction Added"
        if isIncome {
            content.body = "Received $\(String(format: "%.2f", amount)) from \(merchant)"
        } else {
            content.body = "Added $\(String(format: "%.2f", amount)) at \(merchant)"
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Parsed Transaction Model
struct ParsedTransaction {
    let amount: Double
    let merchant: String
    let date: Date
    let note: String
    let isIncome: Bool
    
    init(amount: Double, merchant: String, date: Date, note: String, isIncome: Bool = false) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.note = note
        self.isIncome = isIncome
    }
}

