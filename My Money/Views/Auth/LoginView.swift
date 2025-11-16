//
//  LoginView.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager: AuthManager
    @State private var isLoading = false
    
    init(authManager: AuthManager) {
        _authManager = StateObject(wrappedValue: authManager)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("My Money")
                        .font(.system(size: 42, weight: .bold))
                    
                    Text("Manage your finances with ease")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)
                
                // Google Sign-In Button
                VStack(spacing: 16) {
                    if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: signInWithGoogle) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "globe")
                                    .font(.title3)
                            }
                            
                            Text(isLoading ? "Signing in..." : "Continue with Google")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our Terms of Service")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                // Error is handled by authManager
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    LoginView(authManager: AuthManager())
}

