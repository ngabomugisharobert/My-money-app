//
//  AddTransactionView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import UIKit

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    
    @State private var amount: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category? = nil
    @State private var date: Date = Date()
    @State private var note: String = ""
    
    init(context: NSManagedObjectContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section("Transaction Type") {
                    TransactionTypePicker(selectedType: $selectedType)
                        .onChange(of: selectedType) { oldValue, newValue in
                            // Clear selected category when type changes
                            selectedCategory = nil
                            if let userId = sessionViewModel.userId {
                                categoryViewModel.fetchCategories(userId: userId, type: newValue)
                            }
                        }
                        .onChange(of: categoryViewModel.categories) { oldValue, newValue in
                            // Ensure selected category is still valid after categories update
                            if let currentCategory = selectedCategory,
                               !categoryViewModel.getCategories(for: selectedType).contains(where: { $0.id == currentCategory.id }) {
                                selectedCategory = nil
                            }
                        }
                }
                
                Section("Category") {
                    let filteredCategories = categoryViewModel.getCategories(for: selectedType)
                    if filteredCategories.isEmpty {
                        Text("No categories available")
                            .foregroundColor(.secondary)
                    } else {
                        CategoryPicker(
                            categories: filteredCategories,
                            selectedCategory: $selectedCategory
                        )
                    }
                }
                
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Note (Optional)") {
                    TextField("Add a note", text: $note)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissKeyboard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismissKeyboard()
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let userId = sessionViewModel.userId {
                    categoryViewModel.fetchCategories(userId: userId, type: selectedType)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        return selectedCategory != nil
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0,
              let category = selectedCategory else { return }
        
        dismissKeyboard()
        
        Task {
            await transactionViewModel.addTransactionWithSync(
                amount: amountValue,
                type: selectedType,
                category: category,
                date: date,
                note: note.isEmpty ? nil : note,
                userId: sessionViewModel.userId
            )
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel
    let transaction: Transaction
    let context: NSManagedObjectContext
    
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    
    @State private var amount: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category? = nil
    @State private var date: Date = Date()
    @State private var note: String = ""
    
    init(transaction: Transaction, context: NSManagedObjectContext) {
        self.transaction = transaction
        self.context = context
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
        
        _amount = State(initialValue: String(transaction.amount))
        _selectedType = State(initialValue: transaction.transactionType)
        _selectedCategory = State(initialValue: transaction.category)
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note ?? "")
    }
    
    var body: some View {
        Form {
            Section("Amount") {
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
            }
            
            Section("Transaction Type") {
                TransactionTypePicker(selectedType: $selectedType)
                    .onChange(of: selectedType) { oldValue, newValue in
                        // Clear selected category if it doesn't match the new type
                        if let currentCategory = selectedCategory,
                           currentCategory.type != newValue.rawValue {
                            selectedCategory = nil
                        }
                        if let userId = sessionViewModel.userId {
                            categoryViewModel.fetchCategories(userId: userId, type: newValue)
                        }
                    }
            }
            
            Section("Category") {
                let filteredCategories = categoryViewModel.getCategories(for: selectedType)
                if filteredCategories.isEmpty {
                    Text("No categories available")
                        .foregroundColor(.secondary)
                } else {
                    CategoryPicker(
                        categories: filteredCategories,
                        selectedCategory: $selectedCategory
                    )
                }
            }
            
            Section("Date") {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            
            Section("Note (Optional)") {
                TextField("Add a note", text: $note)
            }
            
            Section {
                Button("Delete Transaction", role: .destructive) {
                    dismissKeyboard()
                    Task {
                        await transactionViewModel.deleteTransactionWithSync(
                            transaction,
                            userId: sessionViewModel.userId
                        )
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Edit Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    dismissKeyboard()
                    saveTransaction()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            if let userId = sessionViewModel.userId {
                categoryViewModel.fetchCategories(userId: userId, type: selectedType)
            }
        }
    }
    
    private var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else { return false }
        return selectedCategory != nil
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount), amountValue > 0,
              let category = selectedCategory else { return }
        
        dismissKeyboard()
        
        Task {
            await transactionViewModel.updateTransactionWithSync(
                transaction,
                amount: amountValue,
                type: selectedType,
                category: category,
                date: date,
                note: note.isEmpty ? nil : note,
                userId: sessionViewModel.userId
            )
            
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    AddTransactionView(context: CoreDataManager.shared.viewContext)
}

