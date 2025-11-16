//
//  CategoryPicker.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct CategoryPicker: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    let columns = [GridItem(.adaptive(minimum: 80))]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(categories, id: \.id) { category in
                CategoryButton(
                    category: category,
                    isSelected: isCategorySelected(category)
                ) {
                    withAnimation {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    private func isCategorySelected(_ category: Category) -> Bool {
        guard let selected = selectedCategory else { return false }
        return selected.id == category.id
    }
}

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.colorValue)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.iconName)
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                Text(category.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let context = CoreDataManager.shared.viewContext
    let category = Category(context: context)
    category.name = "Food"
    category.icon = "fork.knife"
    category.color = "#FF6B6B"
    
    return CategoryPicker(categories: [category], selectedCategory: .constant(category))
        .padding()
}

