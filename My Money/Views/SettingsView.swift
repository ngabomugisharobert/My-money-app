//
//  SettingsView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var categoryViewModel: CategoryViewModel
    
    @State private var showingAddCategory = false
    @State private var isLoggingOut = false
    
    init(context: NSManagedObjectContext) {
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Categories") {
                    ForEach(categoryViewModel.categories, id: \.id) { category in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(category.colorValue)
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: category.iconName)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                
                                Text(category.type == TransactionType.income.rawValue ? "Income" : "Expense")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if category.isDefault {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCategories)
                    
                    Button(action: { showingAddCategory = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Custom Category")
                        }
                    }
                }
                
                Section("Features") {
                    NavigationLink(destination: SMSImportView(context: viewContext)) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Import from SMS")
                        }
                    }
                }
                
                Section("Account") {
                    NavigationLink(destination: ProfileView(context: viewContext)) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("View Profile")
                        }
                    }
                    
                    Button(action: logout) {
                        HStack {
                            if isLoggingOut {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Sign Out")
                                .foregroundColor(isLoggingOut ? .secondary : .red)
                        }
                    }
                    .disabled(isLoggingOut)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("App Name")
                        Spacer()
                        Text("My Money")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(
                    context: viewContext,
                    categoryViewModel: categoryViewModel
                )
            }
            .onAppear {
                if let userId = sessionViewModel.userId {
                    categoryViewModel.fetchCategories(userId: userId)
                }
            }
        }
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        Task {
            for index in offsets {
                await categoryViewModel.deleteCategoryWithSync(
                    categoryViewModel.categories[index],
                    userId: sessionViewModel.userId
                )
            }
        }
    }
    
    private func logout() {
        isLoggingOut = true
        Task {
            do {
                try sessionViewModel.authManagerInstance.signOut()
            } catch {
                print("Error signing out: \(error)")
            }
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
    
}

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel
    let context: NSManagedObjectContext
    @ObservedObject var categoryViewModel: CategoryViewModel
    
    @State private var name = ""
    @State private var icon = "folder"
    @State private var color = "#FF6B6B"
    @State private var type: TransactionType = .expense
    
    let icons = ["folder", "star", "heart", "house", "car", "airplane", "gamecontroller", "book", "music.note", "camera"]
    let colors = ["#FF6B6B", "#4ECDC4", "#95E1D3", "#F38181", "#AA96DA", "#FCBAD3", "#A8E6CF", "#51CF66", "#339AF0", "#845EF7", "#FFD43B"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Name") {
                    TextField("Category Name", text: $name)
                }
                
                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { transactionType in
                            Text(transactionType.displayName).tag(transactionType)
                        }
                    }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                        ForEach(icons, id: \.self) { iconName in
                            Button(action: { icon = iconName }) {
                                Image(systemName: iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(icon == iconName ? .blue : .gray)
                                    .frame(width: 50, height: 50)
                                    .background(icon == iconName ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button(action: { color = colorHex }) {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(color == colorHex ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        Task {
            await categoryViewModel.addCustomCategoryWithSync(
                name: name,
                icon: icon,
                color: color,
                type: type,
                userId: sessionViewModel.userId
            )
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    SettingsView(context: CoreDataManager.shared.viewContext)
}

