# Known Limitations & Production Assessment: Between Us

This document transparently defines hardware/OS limitations, background restrictions, and the phased engineering roadmap.

---

## 1. Operating System Constraints & Production Handling

### A. Background Location Tracking
- **Operating System Policy**: Android 14+ and iOS 17+ strictly terminate background GPS listeners unless explicit background execution contracts are satisfied.
- **Between Us Implementation**:
  - **Android**: Configured with `AndroidSettings.foregroundNotificationConfig` creating a persistent foreground notification ("*Between Us Location Active*") with `FOREGROUND_SERVICE_LOCATION`.
  - **iOS**: Configured with `AppleSettings.showBackgroundLocationIndicator: true` and `pauseLocationUpdatesAutomatically: false`.
  - **Movement Filter**: A 25-meter distance filter prevents battery drain by sleeping until significant displacement occurs.
  - **Staleness Tracking**: The UI clearly displays `LIVE`, `LAST UPDATED X MIN AGO`, or `LOCATION SHARING OFF`. Stale coordinates are never mislabeled as live.

### B. Fullscreen Lockscreen Takeovers
- **Operating System Policy**: Neither iOS nor Android 14+ allow background applications to wake a locked screen into a full-bleed application canvas outside of incoming VoIP calls (`CallKit` / `ConnectionService`).
- **Between Us Implementation**:
  - **When App is Open / Foregrounded**: Immediate fullscreen romantic Love Moment overlay with haptic heart particle canvas.
  - **When App is Backgrounded / Locked**: Delivered via high-priority Firebase Cloud Messaging (FCM) heads-up push notification with custom sound/vibration channel. Tapping the notification immediately opens the Love Moment overlay.

---

## 2. Subsystem Readiness Classification

| Subsystem | Production Classification | Current Reality |
| :--- | :--- | :--- |
| **Authentication & Pairing** | `PRODUCTION-READY` | Real Firebase Auth + Atomic Firestore pairing transaction + persistent session. |
| **Live Location & Distance** | `PRODUCTION-READY` | Native Geolocator + 25m filter + Android Foreground Service + staleness detection. |
| **Push Notifications & Moments** | `PRODUCTION-READY` | FCM high-priority + Cloud Functions triggers + custom channels + 30s cooldown. |
| **Private Chat & Voice Notes** | `PRODUCTION-READY` | Real AAC `.m4a` microphone capture with interruption resilience + Storage upload + Firestore. |
| **Photos & Video Media** | `PRODUCTION-READY` | Photo upload + $\le 50\text{MB}$ video upload with progress stream and size validation. |
| **Shared Music Room** | `PRODUCTION-READY` | `file_picker` user audio import ($\le 25\text{MB}$) + `just_audio` continuous rate slewing ($0.95\times / 1.05\times$) + revision-gated conflict resolution. |
| **Shared Memories Timeline** | `PRODUCTION-READY` | Firestore collection + "On This Day" matching + photo uploads. |
| **Make Up Assistant** | `PRODUCTION-READY` | On-device structured de-escalation communication scripts. |
| **Meeting Countdown** | `PRODUCTION-READY` | Synchronized with NTP server timestamp (`TimeSync.nowSyncedMs`). |
| **WebRTC Voice / Video Calls** | `KNOWN LIMITATION` | Deferred to Post-MVP Phase 4. |

---

## 3. Post-MVP Roadmap (Phase 4 & Beyond)
1. **WebRTC Calling**: Peer-to-peer audio/video call engine integrated with native `CallKit` (iOS) and `ConnectionService` (Android).
2. **Lockscreen Widgets**: iOS Live Activities and Android Glance lockscreen widgets for ambient distance and quick moments.
3. **DRM Licensed Music Catalog**: Integration with legal music APIs (e.g. 7digital / Apple MusicKit SDK) for licensed catalog streaming.
