//
//  LineChart.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct LineChart: View {
    let data: [(month: String, income: Double, expenses: Double)]
    
    private var maxValue: Double {
        let allValues = data.flatMap { [$0.income, $0.expenses] }
        return (allValues.max() ?? 0) * 1.1
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Grid lines
                ForEach(0..<5) { index in
                    let y = height * CGFloat(index) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
                
                // Income line
                if data.count > 1 {
                    Path { path in
                        for (index, item) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height - (height * CGFloat(item.income / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.green, lineWidth: 2)
                    
                    // Income points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        let x = width * CGFloat(index) / CGFloat(data.count - 1)
                        let y = height - (height * CGFloat(item.income / maxValue))
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
                
                // Expenses line
                if data.count > 1 {
                    Path { path in
                        for (index, item) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height - (height * CGFloat(item.expenses / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.red, lineWidth: 2)
                    
                    // Expenses points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        let x = width * CGFloat(index) / CGFloat(data.count - 1)
                        let y = height - (height * CGFloat(item.expenses / maxValue))
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }
}

#Preview {
    LineChart(data: [
        ("Jan", 5000, 3000),
        ("Feb", 4500, 3500),
        ("Mar", 6000, 4000),
        ("Apr", 5500, 3200),
        ("May", 5000, 3800),
        ("Jun", 4800, 3600)
    ])
    .padding()
}

