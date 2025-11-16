//
//  TransactionRow.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(transaction.category?.colorValue ?? Color.gray)
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.category?.iconName ?? "folder")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryName)
                    .font(.headline)
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(formatDate(transaction.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(transaction.amount))
                    .font(.headline)
                    .foregroundColor(transaction.transactionType == .income ? .green : .red)
                
                Text(transaction.transactionType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let context = CoreDataManager.shared.viewContext
    let transaction = Transaction(context: context)
    transaction.amount = 50.0
    transaction.type = "expense"
    transaction.date = Date()
    
    return TransactionRow(transaction: transaction)
        .padding()
}

