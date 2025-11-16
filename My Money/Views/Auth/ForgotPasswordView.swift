//
//  ForgotPasswordView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter your email address and we'll send you a link to reset your password.")
                }
                
                if let errorMessage = authManager.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if showSuccess {
                    Section {
                        Text("Password reset email sent! Check your inbox.")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: resetPassword) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Send Reset Link")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || email.isEmpty)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        Task {
            do {
                try await authManager.resetPassword(email: email)
                await MainActor.run {
                    showSuccess = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView(authManager: AuthManager())
}

