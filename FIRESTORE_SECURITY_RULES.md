# Firestore Security Rules

## Overview
These security rules ensure that users can only access their own data in Firestore.

## Rules

Copy and paste these rules into your Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users collection - users can only read/write their own data
    match /users/{userId} {
      // Allow users to read/write their own user document
      allow read, write: if isOwner(userId);
      
      // Transactions subcollection
      match /transactions/{transactionId} {
        allow read, write: if isOwner(userId);
      }
      
      // Categories subcollection
      match /categories/{categoryId} {
        allow read, write: if isOwner(userId);
      }
      
      // Preferences subcollection
      match /preferences/{preferenceId} {
        allow read, write: if isOwner(userId);
      }
    }
  }
}
```

## Testing

### Test Cases

1. **User can read their own data**
   - ✅ User A can read User A's transactions
   - ❌ User A cannot read User B's transactions

2. **User can write their own data**
   - ✅ User A can create/update/delete User A's transactions
   - ❌ User A cannot create/update/delete User B's transactions

3. **Unauthenticated users**
   - ❌ Unauthenticated users cannot read any data
   - ❌ Unauthenticated users cannot write any data

## Deployment

1. Go to Firebase Console
2. Navigate to Firestore Database → Rules
3. Paste the rules above
4. Click "Publish"
5. Test using the Firebase Console Simulator

## Important Notes

- These rules enforce user-level data isolation
- All data is stored under `/users/{userId}/`
- Each user can only access their own subcollections
- Rules are evaluated on every read/write operation

