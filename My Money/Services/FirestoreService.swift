//
//  FirestoreService.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import Combine
import FirebaseFirestore

class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Transactions
    
    func listenToTransactions(userId: String, completion: @escaping (Result<[TransactionData], Error>) -> Void) -> ListenerRegistration {
        let listener = db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let transactions = documents.compactMap { doc -> TransactionData? in
                    try? doc.data(as: TransactionData.self)
                }
                completion(.success(transactions))
            }
        
        listeners.append(listener)
        return listener
    }
    
    func addTransaction(userId: String, transaction: TransactionData, documentId: String) async throws {
        // Use provided document ID for the path
        // @DocumentID property should remain nil - Firestore will populate it when reading
        let docRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .document(documentId)
        
        // Ensure @DocumentID is nil before saving
        var transactionData = transaction
        transactionData.id = nil
        
        try docRef.setData(from: transactionData)
    }
    
    func updateTransaction(userId: String, transaction: TransactionData, documentId: String) async throws {
        // Use provided document ID for the path
        // @DocumentID property should remain nil - Firestore will populate it when reading
        let docRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .document(documentId)
        
        // Ensure @DocumentID is nil before saving
        var transactionData = transaction
        transactionData.id = nil
        
        try docRef.setData(from: transactionData, merge: true)
    }
    
    func deleteTransaction(userId: String, transactionId: String) async throws {
        let docRef = db.collection("users")
            .document(userId)
            .collection("transactions")
            .document(transactionId)
        
        try await docRef.delete()
    }
    
    // MARK: - Categories
    
    func listenToCategories(userId: String, completion: @escaping (Result<[CategoryData], Error>) -> Void) -> ListenerRegistration {
        let listener = db.collection("users")
            .document(userId)
            .collection("categories")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let categories = documents.compactMap { doc -> CategoryData? in
                    try? doc.data(as: CategoryData.self)
                }
                completion(.success(categories))
            }
        
        listeners.append(listener)
        return listener
    }
    
    func addCategory(userId: String, category: CategoryData, documentId: String) async throws {
        // Use provided document ID for the path
        // @DocumentID property should remain nil - Firestore will populate it when reading
        let docRef = db.collection("users")
            .document(userId)
            .collection("categories")
            .document(documentId)
        
        // Ensure @DocumentID is nil before saving
        var categoryData = category
        categoryData.id = nil
        
        try docRef.setData(from: categoryData)
    }
    
    func updateCategory(userId: String, category: CategoryData, documentId: String) async throws {
        // Use provided document ID for the path
        // @DocumentID property should remain nil - Firestore will populate it when reading
        let docRef = db.collection("users")
            .document(userId)
            .collection("categories")
            .document(documentId)
        
        // Ensure @DocumentID is nil before saving
        var categoryData = category
        categoryData.id = nil
        
        try docRef.setData(from: categoryData, merge: true)
    }
    
    func deleteCategory(userId: String, categoryId: String) async throws {
        let docRef = db.collection("users")
            .document(userId)
            .collection("categories")
            .document(categoryId)
        
        try await docRef.delete()
    }
    
    // MARK: - User Preferences
    
    func getUserPreferences(userId: String) async throws -> UserPreferences? {
        let docRef = db.collection("users")
            .document(userId)
            .collection("preferences")
            .document("settings")
        
        let document = try await docRef.getDocument()
        return try? document.data(as: UserPreferences.self)
    }
    
    func saveUserPreferences(userId: String, preferences: UserPreferences) async throws {
        let docRef = db.collection("users")
            .document(userId)
            .collection("preferences")
            .document("settings")
        
        try docRef.setData(from: preferences, merge: true)
    }
    
    // MARK: - Fetch All Data (for sync comparison)
    func fetchAllTransactions(userId: String) async throws -> [TransactionData] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("transactions")
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> TransactionData? in
            try? doc.data(as: TransactionData.self)
        }
    }
    
    func fetchAllCategories(userId: String) async throws -> [CategoryData] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("categories")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> CategoryData? in
            try? doc.data(as: CategoryData.self)
        }
    }
    
    // MARK: - Cleanup
    func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Data Models for Firestore

struct TransactionData: Codable, Identifiable {
    @DocumentID var id: String?
    var amount: Double
    var type: String // "income" or "expense"
    var categoryId: String?
    var categoryName: String?
    var date: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property for UUID conversion
    var uuid: UUID? {
        get {
            id.flatMap { UUID(uuidString: $0) }
        }
        set {
            id = newValue?.uuidString
        }
    }
    
    init(id: String? = nil, amount: Double, type: String, categoryId: String?, categoryName: String?, date: Date, note: String?) {
        self.id = id
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.date = date
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Convenience initializer with UUID
    init(uuid: UUID? = nil, amount: Double, type: String, categoryId: UUID?, categoryName: String?, date: Date, note: String?) {
        self.id = uuid?.uuidString
        self.amount = amount
        self.type = type
        self.categoryId = categoryId?.uuidString
        self.categoryName = categoryName
        self.date = date
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct CategoryData: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var icon: String?
    var color: String?
    var type: String // "income" or "expense"
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Computed property for UUID conversion
    var uuid: UUID? {
        get {
            id.flatMap { UUID(uuidString: $0) }
        }
        set {
            id = newValue?.uuidString
        }
    }
    
    init(id: String? = nil, name: String, icon: String?, color: String?, type: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Convenience initializer with UUID
    init(uuid: UUID? = nil, name: String, icon: String?, color: String?, type: String, isDefault: Bool) {
        self.id = uuid?.uuidString
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct UserPreferences: Codable {
    var currency: String
    var defaultView: String
    var theme: String
    var updatedAt: Date
    
    init(currency: String = "USD", defaultView: String = "dashboard", theme: String = "system") {
        self.currency = currency
        self.defaultView = defaultView
        self.theme = theme
        self.updatedAt = Date()
    }
}

