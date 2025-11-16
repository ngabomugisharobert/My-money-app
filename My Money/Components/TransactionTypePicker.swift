//
//  TransactionTypePicker.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct TransactionTypePicker: View {
    @Binding var selectedType: TransactionType
    
    var body: some View {
        VStack(spacing: 12) {
            TypeButton(
                type: .income,
                isSelected: selectedType == .income,
                action: { selectedType = .income }
            )
            
            TypeButton(
                type: .expense,
                isSelected: selectedType == .expense,
                action: { selectedType = .expense }
            )
        }
    }
}

struct TypeButton: View {
    let type: TransactionType
    let isSelected: Bool
    let action: () -> Void
    
    private var backgroundColor: Color {
        isSelected ? (type == .income ? Color.green.opacity(0.15) : Color.red.opacity(0.15)) : Color(.systemGray6)
    }
    
    private var borderColor: Color {
        isSelected ? (type == .income ? Color.green : Color.red) : Color.clear
    }
    
    private var iconColor: Color {
        type == .income ? Color.green : Color.red
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(isSelected ? 1.0 : 0.3))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(type == .income ? "Money received" : "Money spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(iconColor)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? iconColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        TransactionTypePicker(selectedType: .constant(.income))
        TransactionTypePicker(selectedType: .constant(.expense))
    }
    .padding()
}

