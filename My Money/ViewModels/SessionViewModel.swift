//
//  SessionViewModel.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import Combine
import SwiftUI
import CoreData

import FirebaseAuth

class SessionViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var isLoading = true
    @Published var isSyncing = false
    @Published var syncProgress: String = "Initializing..."
    
    private let authManager = AuthManager()
    private var cancellables = Set<AnyCancellable>()
    private var lastSyncedUserId: String?
    
    init() {
        setupAuthObserver()
    }
    
    private func setupAuthObserver() {
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        authManager.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                // Perform sync check when user is set (on login)
                // Only sync if this is a new user login (not already synced)
                if let user = user, self?.lastSyncedUserId != user.uid {
                    self?.lastSyncedUserId = user.uid
                    Task {
                        await self?.performSyncCheck(userId: user.uid)
                    }
                } else if user == nil {
                    // User logged out, reset last synced user
                    self?.lastSyncedUserId = nil
                    self?.isSyncing = false
                }
            }
            .store(in: &cancellables)
        
        // Initial load check - wait for auth state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Only set loading to false if not syncing
            if !self.isSyncing {
                self.isLoading = false
            }
        }
    }
    
    private func performSyncCheck(userId: String) async {
        await MainActor.run {
            self.isSyncing = true
            self.syncProgress = "Connecting to Firestore..."
        }
        
        let syncManager = SyncManager(context: CoreDataManager.shared.viewContext)
        
        // Update progress
        await MainActor.run {
            self.syncProgress = "Fetching transactions..."
        }
        
        do {
            // Small delay to show the message
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                self.syncProgress = "Syncing data..."
            }
            
            try await syncManager.verifyAndSyncFromFirestore(userId: userId)
            
            await MainActor.run {
                self.syncProgress = "Sync complete!"
                // Small delay to show completion message
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isSyncing = false
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.syncProgress = "Sync error: \(error.localizedDescription)"
                print("Error during sync check: \(error.localizedDescription)")
                // Still hide loading even on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isSyncing = false
                    self.isLoading = false
                }
            }
        }
    }
    
    var authManagerInstance: AuthManager {
        return authManager
    }
    
    var userId: String? {
        return authManager.currentUserId
    }
}

