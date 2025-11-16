//
//  BalanceCard.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct BalanceCard: View {
    let balance: Double
    let income: Double
    let expenses: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Balance")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(balance))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(balance >= 0 ? .green : .red)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("Income")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(income))
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                        Text("Expenses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(expenses))
                        .font(.headline)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    BalanceCard(balance: 1500.0, income: 5000.0, expenses: 3500.0)
        .padding()
}

