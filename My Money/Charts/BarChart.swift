//
//  BarChart.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct BarChart: View {
    let data: [(month: String, income: Double, expenses: Double)]
    
    private var maxValue: Double {
        let allValues = data.flatMap { [$0.income, $0.expenses] }
        return (allValues.max() ?? 0) * 1.1 // Add 10% padding
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 8) {
                        // Bars
                        ZStack(alignment: .bottom) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 30, height: 150)
                            
                            VStack(spacing: 2) {
                                // Income bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: 30, height: barHeight(item.income))
                                
                                // Expenses bar
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 30, height: barHeight(item.expenses))
                            }
                        }
                        
                        // Month label
                        Text(item.month)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-45))
                            .frame(width: 40)
                    }
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .green, label: "Income")
                LegendItem(color: .red, label: "Expenses")
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private func barHeight(_ value: Double) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value / maxValue) * 150
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    BarChart(data: [
        ("Jan", 5000, 3000),
        ("Feb", 4500, 3500),
        ("Mar", 6000, 4000),
        ("Apr", 5500, 3200),
        ("May", 5000, 3800),
        ("Jun", 4800, 3600)
    ])
    .padding()
}

