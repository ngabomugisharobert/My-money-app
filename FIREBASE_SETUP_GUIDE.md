# Firebase Setup Guide

## Prerequisites
- Xcode 14.0 or later
- iOS 16.0 or later
- Firebase account

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: "My Money"
4. Follow the setup wizard
5. Enable Google Analytics (optional)

## Step 2: Add iOS App to Firebase

1. In Firebase Console, click "Add app" → iOS
2. Enter your iOS bundle ID (e.g., `com.yourcompany.MyMoney`)
3. Register the app
4. Download `GoogleService-Info.plist`

## Step 3: Add GoogleService-Info.plist to Xcode

1. Open your Xcode project
2. Drag `GoogleService-Info.plist` into the project root
3. Make sure "Copy items if needed" is checked
4. Select your app target
5. Click "Finish"

## Step 4: Add Firebase SDK via Swift Package Manager

1. In Xcode, go to **File → Add Packages...**
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Click "Add Package"
4. Select these products:
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseCore
   - ✅ FirebaseFirestoreSwift (for Codable support)
5. Click "Add Package"

## Step 5: Enable Authentication Providers

In Firebase Console → Authentication → Sign-in method:

### Email/Password
1. Click "Email/Password"
2. Enable "Email/Password"
3. Click "Save"

### Apple Sign-In (Optional)
1. Click "Apple"
2. Enable Apple Sign-In
3. Configure your Apple Developer account
4. Click "Save"

### Google Sign-In (Optional)
1. Click "Google"
2. Enable Google Sign-In
3. Enter your OAuth client ID
4. Click "Save"

## Step 6: Configure Firestore Database

1. In Firebase Console → Firestore Database
2. Click "Create database"
3. Start in **production mode** (we'll add security rules)
4. Choose a location (closest to your users)
5. Click "Enable"

## Step 7: Add Security Rules

1. Go to Firestore Database → Rules
2. Copy the rules from `FIRESTORE_SECURITY_RULES.md`
3. Paste into the rules editor
4. Click "Publish"

## Step 8: Enable Offline Persistence

Firestore offline persistence is already enabled in `My_MoneyApp.swift`:

```swift
let settings = FirestoreSettings()
settings.isPersistenceEnabled = true
Firestore.firestore().settings = settings
```

## Step 9: Test the Setup

1. Build and run the app
2. Try creating an account
3. Add a transaction
4. Check Firebase Console → Firestore Database to see your data

## Troubleshooting

### "GoogleService-Info.plist not found"
- Make sure the file is in the project root
- Check that it's added to your app target

### "Firebase not initialized"
- Make sure `FirebaseApp.configure()` is called in `My_MoneyApp.swift` init

### Authentication not working
- Check that Email/Password is enabled in Firebase Console
- Verify your bundle ID matches Firebase project

### Firestore permission denied
- Check security rules are published
- Verify user is authenticated before accessing Firestore

## Next Steps

1. ✅ Authentication is set up
2. ✅ Firestore is configured
3. ✅ Offline persistence is enabled
4. ✅ Security rules are in place

Your app is now ready for cloud sync!

