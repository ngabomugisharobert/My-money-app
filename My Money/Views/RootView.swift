//
//  RootView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData

struct RootView: View {
    @StateObject private var sessionViewModel = SessionViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        Group {
            if sessionViewModel.isLoading || sessionViewModel.isSyncing {
                LoadingView(progress: sessionViewModel.syncProgress)
            } else if sessionViewModel.isAuthenticated {
                MainTabView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(sessionViewModel)
            } else {
                LoginView(authManager: sessionViewModel.authManagerInstance)
            }
        }
        .onAppear {
            // Initialize default categories when user logs in
            if sessionViewModel.isAuthenticated {
                CoreDataManager.shared.initializeDefaultCategories()
            }
        }
    }
}

struct LoadingView: View {
    let progress: String
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App Icon or Logo
                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse, options: .repeating)
                
                // Loading Indicator
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                // Progress Text
                Text(progress)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Please wait...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
}

