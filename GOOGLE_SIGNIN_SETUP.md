# Google Sign-In Setup Guide

## Overview
The app now uses **Google Sign-In as the ONLY authentication method**. Users can create accounts and sign in exclusively through their Google account.

## Prerequisites
- Xcode 14.0 or later
- iOS 16.0 or later
- Firebase project with Google Sign-In enabled
- GoogleSignIn SDK added via Swift Package Manager

## Step 1: Add GoogleSignIn SDK

1. In Xcode, go to **File → Add Packages...**
2. Enter: `https://github.com/google/GoogleSignIn-iOS`
3. Click "Add Package"
4. Select **GoogleSignIn** product
5. Click "Add Package"

## Step 2: Enable Google Sign-In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication → Sign-in method**
4. Click on **Google**
5. Enable Google Sign-In
6. Enter your **Support email**
7. Click **Save**

## Step 3: Configure OAuth Client ID

1. In Firebase Console, go to **Project Settings → General**
2. Scroll down to **Your apps** section
3. Find your iOS app
4. Copy the **OAuth 2.0 Client ID** (it should be in `GoogleService-Info.plist` as `CLIENT_ID`)

## Step 4: Add URL Scheme to Xcode

1. Open your Xcode project
2. Select your app target
3. Go to **Info** tab
4. Expand **URL Types**
5. Click **+** to add a new URL Type
6. Set:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: Your reversed client ID from `GoogleService-Info.plist`
     - Format: `com.googleusercontent.apps.YOUR-CLIENT-ID`
     - You can find this in `GoogleService-Info.plist` under `REVERSED_CLIENT_ID`

## Step 5: Verify GoogleService-Info.plist

Make sure your `GoogleService-Info.plist` contains:
- `CLIENT_ID` (OAuth 2.0 Client ID)
- `REVERSED_CLIENT_ID` (for URL scheme)

## Step 6: Test the Implementation

1. Build and run the app
2. You should see a "Continue with Google" button
3. Tap it to start the Google Sign-In flow
4. After signing in, you should be authenticated and see the main app

## How It Works

1. **User taps "Continue with Google"**
   - Opens Google Sign-In flow
   - User selects their Google account
   - Google returns ID token and access token

2. **Firebase Authentication**
   - App creates Firebase credential using Google tokens
   - Signs user into Firebase
   - Creates/updates user account in Firebase Auth

3. **Automatic Account Creation**
   - If user doesn't have an account, Firebase automatically creates one
   - If user already has an account, they're signed in
   - No separate "Sign Up" flow needed

## Troubleshooting

### "Firebase client ID not found"
- Make sure `GoogleService-Info.plist` is in your project
- Verify it's added to your app target
- Check that `CLIENT_ID` exists in the plist

### "Unable to get root view controller"
- This is a rare error that can occur during app launch
- Try again after the app is fully loaded

### Google Sign-In button doesn't appear
- Check that GoogleSignIn SDK is properly added
- Verify imports are correct
- Check console for any errors

### Sign-in flow doesn't complete
- Verify URL scheme is configured correctly
- Check that Google Sign-In is enabled in Firebase Console
- Ensure OAuth client ID is correct

## Security Notes

- All authentication is handled by Google and Firebase
- User data is stored securely in Firestore
- No passwords are stored locally
- Google handles all password management

## Next Steps

After setup:
1. ✅ Test Google Sign-In flow
2. ✅ Verify user data syncs to Firestore
3. ✅ Test sign out functionality
4. ✅ Test on multiple devices (same Google account)

