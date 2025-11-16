//
//  ProfileView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @StateObject private var transactionViewModel: TransactionViewModel
    
    @State private var showingEditProfile = false
    @State private var showingDeleteAccount = false
    
    init(context: NSManagedObjectContext) {
        _transactionViewModel = StateObject(wrappedValue: TransactionViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Picture
                        if let user = sessionViewModel.currentUser,
                           let photoURL = user.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                            .shadow(radius: 5)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 100)
                                .overlay(Circle().stroke(Color.blue, lineWidth: 3))
                        }
                        
                        // Display Name
                        Text(sessionViewModel.currentUser?.displayName ?? sessionViewModel.currentUser?.email?.components(separatedBy: "@").first ?? "User")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Email
                        if let email = sessionViewModel.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Statistics Cards
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Total Balance",
                                value: formatCurrency(transactionViewModel.balance),
                                icon: "dollarsign.circle.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Total Income",
                                value: formatCurrency(transactionViewModel.totalIncome),
                                icon: "arrow.down.circle.fill",
                                color: .green
                            )
                        }
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Total Expenses",
                                value: formatCurrency(transactionViewModel.totalExpenses),
                                icon: "arrow.up.circle.fill",
                                color: .red
                            )
                            
                            StatCard(
                                title: "Transactions",
                                value: "\(transactionViewModel.transactions.count)",
                                icon: "list.bullet",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Account Actions
                    VStack(spacing: 12) {
                        Button(action: { showingEditProfile = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                        
                        NavigationLink(destination: SettingsView(context: viewContext)) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("Settings")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                        
                        NavigationLink(destination: SMSSampleManagerView(context: viewContext)) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("SMS Sample Manager")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    
                    // Account Management
                    VStack(spacing: 12) {
                        Button(action: { showingDeleteAccount = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if let userId = sessionViewModel.userId {
                    transactionViewModel.fetchTransactions(userId: userId)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .alert("Delete Account", isPresented: $showingDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await sessionViewModel.authManagerInstance.deleteAccount()
            } catch {
                print("Error deleting account: \(error)")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    @State private var displayName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(sessionViewModel.currentUser?.email ?? "No email")
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Display Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || displayName.isEmpty)
                }
            }
            .onAppear {
                displayName = sessionViewModel.currentUser?.displayName ?? ""
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                try await sessionViewModel.authManagerInstance.updateProfile(displayName: displayName)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ProfileView(context: CoreDataManager.shared.viewContext)
        .environmentObject(SessionViewModel())
}

