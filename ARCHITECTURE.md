# Architecture & System Design: Between Us

## 1. Clean Architecture Layers

The Flutter application strictly isolates presentation, state management, domain logic, and data access:

```
[Presentation (UI / Screens / Widgets)]
                     │
                     ▼
[State Management (ChangeNotifier / Provider)]
                     │
                     ▼
[Domain Services (ProximityEngine, TimeSync, MomentsEngine)]
                     │
                     ▼
[Repositories (AuthRepo, CoupleRepo, LocationRepo, ChatRepo, MusicRepo)]
                     │
                     ▼
[Native Plugins / Cloud Backend (Geolocator, JustAudio, Record, Firebase)]
```

---

## 2. Realtime Synchronization & Event Model

### A. Location Streaming & Battery Management
- **Native OS Engine**: Utilizes `geolocator` with `LocationAccuracy.balanced` and `distanceFilter: 25` meters.
- **Write Policy**: Coordinates are only written to `/couples/{coupleId}/locations/{userId}` when the user undergoes meaningful movement or an activity state transition.
- **Privacy Minimization**: Only the latest permitted location document is stored per user. Historical tracks are never written to Firestore.

### B. Proximity Engine with Hysteresis
To prevent false-positive boundary flipping from indoor GPS drift:
- **Accuracy Gate**: Only readings with horizontal accuracy $\le 30\text{m}$ trigger proximity evaluation.
- **Hysteresis Thresholds**:
  - `Together`: Enter $\le 60\text{m}$, Exit $> 120\text{m}$
  - `Very Close`: Enter $\le 500\text{m}$, Exit $> 600\text{m}$
  - `Nearby`: Enter $\le 5\text{km}$, Exit $> 6\text{km}$
  - `Getting Closer`: Enter $\le 50\text{km}$, Exit $> 60\text{km}$
  - `Long Distance`: $> 60\text{km}$

### C. Drift-Free NTP Music Synchronization
- Device clocks calculate server offset $T_{\text{offset}} = T_{\text{server}} - T_{\text{client}}$ during heartbeat handshakes.
- When partner A adjusts playback or seeks, a new `MusicSession` revision is committed.
- **Drift Correction Matrix**:
  - $\Delta < 300\text{ms}$: Synchronized (no adjustment).
  - $300\text{ms} \le \Delta \le 1500\text{ms}$: Slews playback rate to $0.95\times$ or $1.05\times$ to avoid audio clicks.
  - $\Delta > 1500\text{ms}$: Performs a hard seek to estimated server position.

---

## 3. Real vs. Simulated Status Matrix

| Subsystem | Implemented Mobile Status | Backend Integration | Native Hardware Plugin |
| :--- | :--- | :--- | :--- |
| **Authentication** | `IMPLEMENTED` | Firebase Auth | Secure Session Storage |
| **Couple Pairing** | `IMPLEMENTED` | Firestore Atomic Handshake | Deep Link Intent Filter |
| **Live Location** | `IMPLEMENTED` | Firestore Subcollection | `geolocator` |
| **Push Notifications** | `IMPLEMENTED` | FCM + Cloud Functions | `firebase_messaging` |
| **Love Moments** | `IMPLEMENTED` | Firestore + FCM | `vibration` + Canvas Particles |
| **Private Chat** | `IMPLEMENTED` | Firestore Collection | Cache SQLite |
| **Voice Notes** | `IMPLEMENTED` | Firebase Storage | `record` (AAC/M4A) |
| **Music Room** | `IMPLEMENTED` | Firestore Session Doc | `just_audio` |
| **Memories Wall** | `IMPLEMENTED` | Firestore + Firebase Storage | `image_picker` |
| **WebRTC Calls** | `KNOWN LIMITATION` | Phase 4 Architecture | Planned WebRTC |
