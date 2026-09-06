# Between Us — Private Long-Distance Couple App

An intimate, emotionally intelligent, and secure private application engineered specifically for exactly two connected partners.

> **“We don’t help couples talk. We help them feel close when they can’t be together.”**

---

## 📱 Mobile Architecture & Status Summary

**Between Us** is built in Flutter with native Android and iOS platform configurations, connected to a real cloud infrastructure (Firebase Auth, Cloud Firestore, Cloud Functions, Firebase Storage, and Firebase Cloud Messaging).

### Implemented Subsystems
1. **Authentication & Couple Pairing**: Firebase Auth (Email/Password & Token Refresh) + Atomic Firestore pairing transaction with persistent sessions across restarts.
2. **Battery-Aware Location**: Native `geolocator` integration with 25m distance filter, Android Foreground Service notifications, iOS background location indicator, and real-time staleness labels (`LIVE`, `LAST UPDATED X MIN AGO`, `LOCATION SHARING OFF`).
3. **Instant Love Moments**: High-priority push notifications and fullscreen haptic heart animations for *Miss You*, *Hug*, *Kiss*, and *Love Notes* with 30-second spam prevention cooldowns.
4. **Private Chat & Media**: Real Firestore message streaming with native AAC microphone voice recordings (`record` plugin), photo uploads, and $\le 50\text{MB}$ video sharing.
5. **Shared Music Room**: Real user audio file import (`file_picker` $\to$ Firebase Storage $\le 25\text{MB}$) + `just_audio` player + NTP clock drift rate slewing ($0.95\times / 1.05\times$) with revision-gated race condition conflict resolution.
6. **Shared Story Timeline**: Private memories with photos, dates, locations, and "On This Day" nostalgic resurfacing.
7. **Make Up Communication Assistant**: Non-manipulative de-escalation scripts when a partner feels upset.

---

## 🚀 Mobile Build Commands

```bash
# Get dependencies
flutter pub get

# Build Android APK for direct phone installation / testing
flutter build apk --release

# Build Android App Bundle (AAB) for Google Play Console
flutter build appbundle --release

# Build iOS Archive for Xcode / TestFlight (requires macOS + Xcode)
flutter build ipa --release
```

---

## 📚 Project Documentation

- **[AUDIT_REPORT.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/AUDIT_REPORT.md)** — Strict engineering audit and subsystem status matrix.
- **[PHYSICAL_DEVICE_TEST_REPORT.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/PHYSICAL_DEVICE_TEST_REPORT.md)** — 27-point physical dual-device verification test plan.
- **[ARCHITECTURE.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/ARCHITECTURE.md)** — Clean architecture layers, data flow, and NTP clock sync formulas.
- **[SECURITY.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/SECURITY.md)** — Server-enforced couple isolation, Firestore security rules, and data retention policies.
- **[SETUP.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/SETUP.md)** — Step-by-step guide for Firebase setup, security rules deployment, and FlutterFire configuration.
- **[KNOWN_LIMITATIONS.md](file:///C:/Users/Jeet/.gemini/antigravity/scratch/between_us/KNOWN_LIMITATIONS.md)** — OS constraints, background limits, and phased roadmap.
