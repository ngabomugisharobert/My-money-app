//
//  DashboardView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    
    init(context: NSManagedObjectContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Balance Card
                    BalanceCard(
                        balance: transactionViewModel.balance,
                        income: transactionViewModel.totalIncome,
                        expenses: transactionViewModel.totalExpenses
                    )
                    .padding(.horizontal)
                    
                    // Recent Transactions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                            Spacer()
                            NavigationLink("See All", destination: TransactionsListView(context: viewContext))
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        if transactionViewModel.transactions.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("No transactions yet")
                                    .foregroundColor(.secondary)
                                Text("Tap + to add your first transaction")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(transactionViewModel.transactions.prefix(5)), id: \.id) { transaction in
                                TransactionRow(transaction: transaction)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("My Money")
            .onAppear {
                if let userId = sessionViewModel.userId {
                    // Only fetch recent transactions for dashboard (limit to 10)
                    transactionViewModel.fetchTransactions(userId: userId, limit: 10)
                }
            }
        }
    }
}

#Preview {
    DashboardView(context: CoreDataManager.shared.viewContext)
}

