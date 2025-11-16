//
//  PieChart.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct PieChart: View {
    let data: [(category: Category, amount: Double, color: Color)]
    let total: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    PieSlice(
                        startAngle: angle(for: index),
                        endAngle: angle(for: index + 1)
                    )
                    .fill(item.color)
                    .overlay(
                        PieSlice(
                            startAngle: angle(for: index),
                            endAngle: angle(for: index + 1)
                        )
                        .stroke(Color.white, lineWidth: 2)
                    )
                    .scaleEffect(selectedIndex == index ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: selectedIndex)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    @State private var selectedIndex: Int? = nil
    
    private func angle(for index: Int) -> Angle {
        var currentAngle: Double = -90 // Start from top
        for i in 0..<index {
            if i < data.count {
                let percentage = data[i].amount / total
                currentAngle += percentage * 360
            }
        }
        return Angle(degrees: currentAngle)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    let context = CoreDataManager.shared.viewContext
    let cat1 = Category(context: context)
    cat1.id = UUID()
    cat1.name = "Food"
    cat1.color = "#FF6B6B"
    
    let cat2 = Category(context: context)
    cat2.id = UUID()
    cat2.name = "Transport"
    cat2.color = "#4ECDC4"
    
    return PieChart(
        data: [
            (cat1, 500, Color(hex: "#FF6B6B")),
            (cat2, 300, Color(hex: "#4ECDC4"))
        ],
        total: 800
    )
    .padding()
}

