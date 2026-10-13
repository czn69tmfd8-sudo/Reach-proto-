# REACH connectivity prototype 0.2

Status: planning / backend setup. The live `main` branch remains the working local camera preview.

## Goal
Two consenting people on separate iPhones establish a live WebRTC audio/video connection. The session owner starts a session deliberately. A previously authorized partner can join that active session without the owner tapping to answer. Either participant can end it.

## Proposed architecture
- Frontend: static HTTPS page on GitHub Pages, Safari on iPhone.
- Firebase Authentication: identify both participants. Do not rely on a shared room ID as authorization.
- Cloud Firestore: exchange WebRTC offers, answers and ICE candidates (signaling); enforce per-session access with Firebase security rules.
- WebRTC: media transport. Evaluate TURN relay for networks where direct connectivity fails.
- Session expiry and revocation: time-limited grants, session owner can revoke partner access at any time. Access decisions must be enforced by backend rules, not only frontend buttons.

## Test sequence
1. Configure Firebase project and Authentication; create test identities for both partners.
2. Write and validate restrictive Firestore rules. Do not publish unrestricted read/write rules.
3. Implement authenticated room creation and offer/answer/ICE signaling on this development branch.
4. Test one-way video across two iPhones on different networks, then two-way audio/video.
5. Test unauthorized access, expired grants, revocation, ending sessions, and reconnects.
6. Test iOS screen lock/background restrictions and overnight reliability. Do not claim that iOS Safari can stream overnight until validated.

## Privacy boundaries
- No hidden activation of the camera/microphone: the owner must explicitly start a session.
- No automatic remote activation when a session is off.
- Silent joining means no incoming-call ringtone or answer tap, **not** covert capture: provide clear in-app status and controls.
- Never commit Firebase service account credentials, private keys, TURN secrets or other secrets to this public repository.
- Firebase web config is not a secret, but security must come from Authentication and Firestore rules.
- No recording or uploads of media in the prototype.

## Deployment
Keep `main` stable. Develop on `dev/connectivity-v02`, test safely, and merge only after the end-to-end and security checks pass.
