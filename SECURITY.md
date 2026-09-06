# Security & Privacy Model: Between Us

## 1. Server-Enforced Couple Isolation (RBAC)

> **Important Terminology Note**: Between Us utilizes **Server-Side Access-Controlled Isolation (RBAC/ABAC)** via Firestore Security Rules and Storage Security Rules, **not client-side Zero-Knowledge / End-to-End Encryption (E2EE)**. All data stored in Cloud Firestore is encrypted in transit (TLS 1.3) and at rest by Google Cloud, but plaintext fields are evaluated by Firebase security rules.

- Every relationship is strictly isolated within `/couples/{coupleId}/`.
- Random authenticated users cannot query or enumerate other couples' private data.
- Database IDs are cryptographically non-predictable UUIDv4 strings.

---

## 2. Firestore Security Rules Verification

All reads and writes to subcollections (`locations`, `messages`, `moments`, `music`, `memories`) enforce server-side validation:

```javascript
function isCoupleMember(coupleId) {
  return request.auth != null && 
    request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.members;
}
```

If an unauthorized user attempts to read or write another couple's data, Firestore immediately rejects the operation with `PERMISSION_DENIED`.

---

## 3. Storage Rules & Media Privacy

- Voice notes and memory photos are uploaded to `couples/{coupleId}/*`.
- Permanent public URLs without authentication tokens are disallowed.
- Downloading media requires an authenticated token verified by the couple's membership rule.

---

## 4. Minimum Location Retention Policy

- **No Breadcrumbs / Trails**: The app only keeps one document per user in `/couples/{coupleId}/locations/{userId}` representing their latest permitted coordinate.
- **Immediate Disconnect Cleanup**: When a couple unpairs or deletes their space, the `onCoupleUnpaired` Cloud Function immediately deletes all associated location records and revokes device tokens.
- **Opt-In / Opt-Out**: Users can revoke location sharing at any time from the app settings, which clears their location document on the server.
