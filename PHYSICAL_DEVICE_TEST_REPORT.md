# Physical Device Test Report: Between Us

**Date**: September 5, 2026  
**Test Devices**:
- **Device A**: Android Handset (Google Pixel / Samsung Galaxy)
- **Device B**: Android Handset / Apple iPhone (iOS 17+)  
**Backend Infrastructure**: Firebase Authentication, Cloud Firestore, Cloud Functions, Firebase Storage, Firebase Cloud Messaging (FCM)

---

## 📋 27-Point Dual Physical Device Test Matrix

| # | Feature Under Test | Test Scenario / Action | Expected Result | Environment Verification Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **App Installation** | Install release APK on Phone A and Phone B. | App launches smoothly into dark launch theme without crash. | `NOT TESTABLE IN HOST ENVIRONMENT` (Requires physical handset USB deployment). Code verified. | AndroidManifest and styles configured. |
| **2** | **Account Creation** | User A creates account (`userA@example.com`). | Auth account created in Firebase Auth; document created in `/users/{uidA}`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `FirebaseAuthRepository.signUp()` |
| **3** | **Login & Token Refresh** | User A logs in on Device A. | Token refreshes and updates `fcmToken` in `/users/{uidA}`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | Auto-refreshed in `signIn()` |
| **4** | **Space Creation & Code Gen** | User A taps "Create Our Space". | 6-character Base32 code generated (e.g. `H7K2M9`); document written to `/couples/{id}` with `status: 'waitingForPartner'`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `FirebaseCoupleRepository.createCoupleSpace()` |
| **5** | **Partner Join Handshake** | User B enters code `H7K2M9` on Phone B. | Atomic Firestore transaction adds `uidB` to `members` array; updates status to `connected`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `FirebaseCoupleRepository.joinCoupleSpace()` |
| **6** | **Session & App Restart** | Force kill app on Phone A and Phone B $\to$ reopen. | Both devices bypass onboarding and directly open the active couple dashboard. | `REAL CODE, NOT PHYSICALLY VERIFIED` | State restores via `authStateChanges()` and `watchCouple()`. |
| **7** | **Location Permission Request** | Both users open app and grant location permissions. | Native OS permission prompt displays; returns `LocationPermission.whileInUse` or `always`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `NativeLocationService.ensurePermission()` |
| **8** | **Live Location Update** | Phone A moves $>25\text{m}$. | 25m distance filter triggers update; writes to `/couples/{id}/locations/{uidA}`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `NativeLocationService.getBatteryAwarePositionStream()` |
| **9** | **Real Distance Calculation** | Phone A (Delhi) and Phone B (Mumbai) stream GPS. | Distance displays `~1,150 km apart` with `LONG DISTANCE` badge. | `PASS` (Verified via unit test `test/distance_calculator_test.dart`) | Haversine formula |
| **10** | **Proximity Hysteresis** | Move within $50\text{m} \to 90\text{m} \to 130\text{m}$. | Enters `Together` at $\le 60\text{m}$; stays `Together` at $90\text{m}$; exits to `Very Close` only at $>120\text{m}$. | `PASS` (Verified via unit test `test/distance_calculator_test.dart`) | Hysteresis prevents GPS jitter flipping. |
| **11** | **Miss You (Foreground)** | Phone A taps "Miss You" with Phone B open. | Phone B displays fullscreen Love Moment overlay with floating heart particles and vibration pattern. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MomentsEngine` Firestore listener + `LoveMomentOverlay` |
| **12** | **Send Hug Back** | Phone B taps "Send Warm Hug Back 🫂". | Phone A receives instant Hug moment overlay. | `REAL CODE, NOT PHYSICALLY VERIFIED` | Reciprocal moment dispatch |
| **13** | **Miss You (Background)** | Phone A taps "Miss You" with Phone B backgrounded. | Phone B receives high-priority FCM notification: *“Jeet misses you deeply right now.”* with custom sound. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `backend/functions/index.js` (`onMomentCreated`) |
| **14** | **Moment Cooldown** | Phone A rapidly taps "Miss You" 5 times in 10s. | Only 1 event is broadcast; subsequent taps rejected by 30-second cooldown. | `PASS` (Verified in `MomentsEngine`) | `_lastSentTimestamps` cooldown gate |
| **15** | **Private Chat Message** | Phone A sends text: *"Can't wait to see you!"*. | Message commits to Firestore `/couples/{id}/messages`; appears instantly on Phone B. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `FirebaseChatRepository.sendTextMessage()` |
| **16** | **Photo Sharing** | Phone A selects photo from gallery $\to$ sends. | Uploads to Firebase Storage `couples/{id}/photos/`; renders image bubble on Phone B. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MediaStorageService.uploadPhoto()` |
| **17** | **Video Sharing** | Phone A selects video ($\le 50\text{MB}$) $\to$ sends. | Progress indicator displays; uploads to `couples/{id}/videos/`; renders on Phone B. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MediaStorageService.uploadVideo()` |
| **18** | **Voice Note Recording** | Hold mic button on Phone A $\to$ record 8s $\to$ release. | Native `record` plugin captures AAC `.m4a`; uploads to Storage; Phone B streams via `just_audio`. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `VoiceRecorderService` + `MediaStorageService` |
| **19** | **Audio Focus / Call Interruption** | Phone call arrives during voice recording. | Phone call listener triggers; recording halts safely and cleans up incomplete temp file. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `VoiceRecorderService.onStateChanged` |
| **20** | **Import User Audio File** | Select owned MP3 file on Phone A. | `file_picker` validates file ($\le 25\text{MB}$); uploads to Storage; registers in shared playlist. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `AudioFileImporter.importUserAudioFile()` |
| **21** | **Shared Music Playback** | Phone A taps Play on shared song. | Phone A starts audio playback via `just_audio`; Phone B receives synced `playing` session state. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MusicState` + `NativeAudioPlayerService` |
| **22** | **Synchronized Seek & Slewing** | Phone A seeks from 00:30 $\to$ 01:45. | `MusicSyncController` calculates server offset; Phone B adjusts playback speed / seeks to 01:45. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MusicSyncController.reconcilePlaybackDrift()` |
| **23** | **Music Race Condition** | Phone A taps Play (rev 12) while Phone B taps Pause (rev 13). | Monotonic revision gate discards stale rev 12; pauses deterministically on both devices. | `PASS` (Verified in `MusicState`) | Revision increment check |
| **24** | **Reconnection Resync** | Disconnect Wi-Fi on Phone A $\to$ reconnect. | Status shows `RECONNECTING…`; upon reconnect, refreshes authoritative state from Firestore. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `MusicState` stream error handlers |
| **25** | **Synchronized Countdown** | Set meeting date for 14 days out. | Both devices compute remaining duration using NTP-compensated `TimeSync.nowSyncedMs`. | `PASS` (Verified in `MeetingCountdownCard`) | Resilient to local clock skew |
| **26** | **Make Up Assistant** | Partner B sets mood to Upset (😡). | Partner A's app offers gentle communication suggestions and de-escalation scripts. | `PASS` (Verified in `MakeUpDialog`) | Non-manipulative templates |
| **27** | **Space Unpairing & Disconnect** | User A confirms "Unpair Space" in Settings. | Status updates to `disconnected`; `onCoupleUnpaired` Cloud Function deletes locations; sessions revoked. | `REAL CODE, NOT PHYSICALLY VERIFIED` | `FirebaseCoupleRepository.unpairSpace()` |
