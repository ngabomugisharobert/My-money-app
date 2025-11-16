//
//  TransactionsListView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import Combine

struct TransactionsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    
    @State private var showingAddTransaction = false
    @State private var selectedFilter: FilterType = .all
    @State private var selectedCategory: Category? = nil
    @State private var selectedMonth: Date = Date()
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case income = "Income"
        case expense = "Expense"
    }
    
    init(context: NSManagedObjectContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                VStack(spacing: 12) {
                    // Filter by type
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(FilterType.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedFilter) {
                        applyFilters()
                    }
                    
                    // Month picker
                    DatePicker("Month", selection: $selectedMonth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)
                        .onChange(of: selectedMonth) {
                            applyFilters()
                        }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))
                
                // Transactions List
                if transactionViewModel.transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No transactions found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try adjusting your filters or add a new transaction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(transactionViewModel.transactions, id: \.id) { transaction in
                            NavigationLink(destination: EditTransactionView(
                                transaction: transaction,
                                context: viewContext
                            )) {
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction, onDismiss: {
                // Refresh the list when the sheet is dismissed
                applyFilters()
            }) {
                AddTransactionView(context: viewContext)
            }
            .onChange(of: sessionViewModel.userId) { oldValue, newValue in
                // Refresh when user changes
                if newValue != nil {
                    applyFilters()
                }
            }
            .onAppear {
                if let userId = sessionViewModel.userId {
                    categoryViewModel.fetchCategories(userId: userId)
                    applyFilters()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TransactionUpdated"))) { _ in
                // Refresh when transaction is updated
                applyFilters()
            }
            .onChange(of: showingAddTransaction) { oldValue, newValue in
                // When sheet is dismissed (newValue becomes false), refresh the list
                if oldValue == true && newValue == false {
                    // Sheet was just dismissed, refresh with current filters
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        applyFilters()
                    }
                }
            }
        }
    }
    
    private func applyFilters() {
        guard let userId = sessionViewModel.userId else { return }
        
        let type: TransactionType? = selectedFilter == .all ? nil : 
            (selectedFilter == .income ? .income : .expense)
        
        // Store current filters in ViewModel for refresh after updates
        transactionViewModel.setCurrentFilters(userId: userId, type: type, month: selectedMonth)
        
        transactionViewModel.fetchTransactions(
            userId: userId,
            filterBy: type,
            month: selectedMonth
        )
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await transactionViewModel.deleteTransactionWithSync(
                    transactionViewModel.transactions[index],
                    userId: sessionViewModel.userId
                )
            }
        }
    }
}

#Preview {
    TransactionsListView(context: CoreDataManager.shared.viewContext)
}

