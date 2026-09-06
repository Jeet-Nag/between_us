# Setup & Deployment Guide: Between Us

## 1. Firebase Project Setup

1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **Create Project** (Name: `between-us-app`).
2. Enable **Firebase Authentication**:
   - Enable **Email/Password** sign-in method.
3. Enable **Cloud Firestore Database**:
   - Select production mode.
   - Choose your nearest cloud region (e.g., `asia-south1` / `us-central1`).
4. Enable **Firebase Storage**:
   - Create the default storage bucket.
5. Enable **Cloud Messaging (FCM)**.

---

## 2. Deploy Backend Security Rules & Cloud Functions

```bash
# 1. Login to Firebase CLI
firebase login

# 2. Select your Firebase project
firebase use --add

# 3. Deploy Firestore & Storage Security Rules
firebase deploy --only firestore:rules,storage:rules

# 4. Deploy Cloud Functions
cd backend/functions
npm install
firebase deploy --only functions
cd ../..
```

---

## 3. Configure Native Mobile Projects

Use the official FlutterFire CLI to link credentials directly to Android and iOS:

```bash
# Activate FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Android and iOS native files
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This automatically generates:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- Updated `lib/firebase_options.dart`

---

## 4. Run on Physical Devices

### Android
```bash
# Connect Android phone via USB with USB Debugging enabled
flutter devices
flutter run -d <device_id>
```

### iOS
```bash
# Open iOS project in Xcode to configure your Apple Developer Team Signing
open ios/Runner.xcworkspace

# Run on physical iPhone
flutter run -d <iphone_id>
```
