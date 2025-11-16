//
//  MainTabView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    // Use StateObject to maintain single instance per view lifecycle
    @StateObject private var transactionViewModel = TransactionViewModel(context: CoreDataManager.shared.viewContext)
    @StateObject private var categoryViewModel = CategoryViewModel(context: CoreDataManager.shared.viewContext)
    
    var body: some View {
        TabView {
            DashboardView(context: viewContext)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TransactionsListView(context: viewContext)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
            
            ReportsView(context: viewContext)
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            
            SettingsView(context: viewContext)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            // Initialize default categories on first launch
            CoreDataManager.shared.initializeDefaultCategories()
            
            // Set up Firestore listeners if user is authenticated
            if let userId = sessionViewModel.userId {
                setupFirestoreListeners(userId: userId)
            }
        }
        .onDisappear {
            // Clean up listeners when view disappears
            transactionViewModel.removeFirestoreListener()
            categoryViewModel.removeFirestoreListener()
        }
    }
    
    private func setupFirestoreListeners(userId: String) {
        // Set up listeners for transactions and categories
        // These will automatically sync data from Firestore to Core Data
        transactionViewModel.setupFirestoreListener(userId: userId)
        categoryViewModel.setupFirestoreListener(userId: userId)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}

