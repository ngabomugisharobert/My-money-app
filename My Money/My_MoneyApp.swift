//
//  My_MoneyApp.swift
//  My Money
//
//  Created by King on 15/11/2025.
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

// MARK: - App Delegate for Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign-In with Firebase client ID
        // Try to get client ID from Firebase options first
        var clientID: String? = FirebaseApp.app()?.options.clientID
        
        // If not found, try to read from GoogleService-Info.plist
        if clientID == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let clientIDValue = plist["CLIENT_ID"] as? String {
                clientID = clientIDValue
            }
        }
        
        // If still not found, try reading REVERSED_CLIENT_ID and extract from it
        if clientID == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let plist = NSDictionary(contentsOfFile: path),
               let reversedClientID = plist["REVERSED_CLIENT_ID"] as? String {
                // REVERSED_CLIENT_ID format: com.googleusercontent.apps.CLIENT-ID
                // Extract the CLIENT-ID part
                let components = reversedClientID.components(separatedBy: ".")
                if components.count >= 4 {
                    clientID = components[3...].joined(separator: ".")
                }
            }
        }
        
        // Configure Google Sign-In if we have a client ID
        if let clientID = clientID {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        } else {
            print("Warning: Google Sign-In client ID not found. Google Sign-In will not work until configured.")
            print("Please add CLIENT_ID to GoogleService-Info.plist or enable Google Sign-In in Firebase Console.")
        }
        
        // Enable Firestore offline persistence with optimized cache size
        let settings = FirestoreSettings()
        let cacheSize = NSNumber(value: 40 * 1024 * 1024) // Reduced to 40 MB cache (was 100 MB)
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: cacheSize)
        Firestore.firestore().settings = settings
        
        return true
    }
    
    // Handle Google Sign-In URL (deprecated in iOS 26.0, but kept for compatibility)
    // URL handling is also done via onOpenURL in the SwiftUI app
    @available(iOS, deprecated: 26.0, message: "Use UIScene lifecycle instead")
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct My_MoneyApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onOpenURL { url in
                    // Handle Google Sign-In URL callback
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
