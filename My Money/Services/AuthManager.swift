//
//  AuthManager.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

class AuthManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name if provided
            if let displayName = displayName {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }
            
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Sign In with Apple
    // Note: Apple Sign-In requires AuthenticationServices framework and proper setup
    // Updated for FirebaseAuth 10.x+ (2024+ API)
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents? = nil) async throws {
        // Use the new FirebaseAuth 10.x+ API
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: fullName
        )
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            DispatchQueue.main.async {
                self.user = result.user
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() async throws {
        // Try to get client ID from Firebase options
        var clientID: String? = FirebaseApp.app()?.options.clientID
        
        // If not found, try to read from GoogleService-Info.plist
        if clientID == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let clientIDValue = plist["CLIENT_ID"] as? String {
                clientID = clientIDValue
            }
        }
        
        guard let clientID = clientID else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In is not configured. Please enable Google Sign-In in Firebase Console and ensure CLIENT_ID is in GoogleService-Info.plist"])
        }
        
        // Configure Google Sign-In if not already configured
        if GIDSignIn.sharedInstance.configuration == nil {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
        
        // Get root view controller synchronously (these are not async operations)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to get root view controller"])
        }
        
        do {
            // Start Google Sign-In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to get ID token"])
            }
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            DispatchQueue.main.async {
                self.user = authResult.user
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        // Get userId before signing out
        let userId = Auth.auth().currentUser?.uid
        
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        // Sign out from Firebase
        try Auth.auth().signOut()
        
        // Clear user data from Core Data
        if let userId = userId {
            CoreDataManager.shared.clearUserData(userId: userId)
        }
        
        DispatchQueue.main.async {
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        do {
            try await user.delete()
            DispatchQueue.main.async {
                self.user = nil
                self.isAuthenticated = false
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(displayName: String? = nil) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user signed in"])
        }
        
        let changeRequest = user.createProfileChangeRequest()
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        try await changeRequest.commitChanges()
        
        DispatchQueue.main.async {
            self.user = Auth.auth().currentUser
        }
    }
    
    // MARK: - Get Current User ID
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
}

