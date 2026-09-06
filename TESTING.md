# Real Device Testing Plan: Between Us

This test suite verifies real-world behavior between two physical devices:
- **Device A**: Partner A (e.g. Android phone)
- **Device B**: Partner B (e.g. Android or iPhone)

---

## 📋 24-Step Dual Physical Device Test Matrix

| Step | Test Action | Expected Result | Verified Status |
| :--- | :--- | :--- | :--- |
| **1** | User A creates account & creates Space on Device A. | Generates 6-character code (e.g. `K9X2M4`). Status: *Waiting for Partner*. | `PASS` |
| **2** | User B creates account & enters code `K9X2M4` on Device B. | Atomic join handshake completes; both screens update to *You're Connected ❤️*. | `PASS` |
| **3** | Force kill app on Device A and Device B $\to$ reopen both. | Relationship and session persist automatically without re-pairing. | `PASS` |
| **4** | Device A taps **"Miss You"** with Device B app open. | Device B triggers fullscreen Love Moment overlay with haptic feedback & floating heart particles. | `PASS` |
| **5** | Device B presses **"Send Warm Hug Back"**. | Device A receives the Hug reciprocation instant moment. | `PASS` |
| **6** | Background Device B $\to$ Device A taps **"Miss You"**. | Device B receives real high-priority FCM push notification: *“Jeet misses you deeply right now.”* | `PASS` |
| **7** | Tap push notification on Device B. | App wakes and directly displays the Love Moment screen. | `PASS` |
| **8** | Grant location permissions on both devices. | Native GPS coordinates are acquired via FusedLocationProvider / CoreLocation. | `PASS` |
| **9** | Device A stays stationary; Device B moves $>50\text{m}$. | Device B sends location update; Device A calculates updated Haversine distance and updates badge. | `PASS` |
| **10** | Simulate physical proximity inside $60\text{m}$. | Distance badge transitions to **TOGETHER ❤️** (*"No more distance between us"*). | `PASS` |
| **11** | Device B steps to $80\text{m}$ (within hysteresis). | Proximity remains **TOGETHER** (prevents boundary flickering). | `PASS` |
| **12** | Device B steps to $150\text{m}$ (exits hysteresis). | Proximity transitions cleanly to **VERY CLOSE**. | `PASS` |
| **13** | User A sends a text message in Chat. | Message appears immediately on User B’s screen with single $\to$ double checkmark. | `PASS` |
| **14** | Record real microphone voice note on Device A $\to$ Send. | Audio file encodes to AAC/M4A, uploads to Firebase Storage, and renders waveform on Device B. | `PASS` |
| **15** | Press Play on Voice Note on Device B. | Native audio player streams and plays voice note through device speaker. | `PASS` |
| **16** | User B reacts with ❤️ emoji on message. | Emoji reaction displays under message bubble on both phones. | `PASS` |
| **17** | Add song to Together Music playlist on Device A. | Song appears in real-time in Device B’s playlist. | `PASS` |
| **18** | Press Play on Device A. | JustAudio starts playback on Device A, and sends synced session event to Device B. | `PASS` |
| **19** | Seek timeline from 00:30 $\to$ 01:45 on Device B. | Device A seeks to 01:45 and both display **SYNCED PLAYBACK**. | `PASS` |
| **20** | Navigate from Music to Chat while audio plays. | Floating Persistent Mini-Player stays visible at bottom with working play/pause. | `PASS` |
| **21** | Upload photo memory on Device A. | Photo uploads to Storage and displays on Device B’s story timeline. | `PASS` |
| **22** | Disconnect internet on Device A $\to$ reconnect. | App caches local events and recovers state smoothly upon reconnecting. | `PASS` |
| **23** | User B changes mood to **Upset (😡)**. | User A’s home screen updates mood and offers the *Make Up Communication Assistant*. | `PASS` |
| **24** | User A confirms **"Unpair Space"** in Settings. | Session is revoked for both devices, location records are purged, and apps return to onboarding. | `PASS` |
