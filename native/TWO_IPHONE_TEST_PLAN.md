# First two-iPhone call acceptance checklist

No physical-device call has been verified. A successful simulator/device compile
is not installation, camera capture, sound delivery, or live pairing evidence.

## Gates

- Owner's paid Apple Developer enrollment must become active. Obtain Team ID,
  owned App ID com.reachprototype.app, both device UDIDs, and protected Codemagic
  signing identities as described in DEVICE_INSTALLATION.md. Do not pay again.
- Keep Google authentication paused. Approved additive staging deployment remains
  pending until authenticated live-baseline and artifact verification are possible.
- Install the same signed staging build on both phones. Check its build/commit,
  project and bundle against CI evidence. No TestFlight upload is configured.

## On the two phones

1. Use two independently authenticated native installations. Confirm identity
   persists after app restart, without transferring existing web pairings.
2. A creates a fresh native code; B explicitly accepts it. Refresh both phones
   and confirm partnership persists. Existing web pair records must stay intact.
3. A explicitly opens a hand; B explicitly takes it. Both grant camera/microphone
   permission intentionally. Do not infer connectivity from signaling completion.
4. Verify moving partner video and intelligible audio in both directions. Each
   person performs a different visible gesture and speaks independently.
5. Check microphone mute, camera off/on, End from either side, backgrounding and
   leaving the call screen. Capture must stop and the old room must not revive.
6. Swap opener/joiner roles and repeat. Never attach a new peer to old SDP/ICE.
7. Interrupt network briefly: recovery may occur within the existing transport's
   20-second window. Permanent failure must stop media. Reconnection after End
   requires another explicit open/join; no automatic or overnight joining.
8. Revoke from each side in separate trials. Verify media stops, old signaling is
   denied, and new native pairing works without changing either web partnership.
9. Verify room expiration denies further native room/ICE access; expired cleanup
   must not erase any newer room pointer. Use a controlled staging fixture for a
   shorter expiry rather than weakening rules or changing production data.
10. Repeat on separate networks. Direct/STUN is implemented; no TURN is configured.
    If NAT traversal fails, record the failure instead of reporting a working call.

Record build SHA, phone/iOS versions, network types, scenario and pass/fail result.
Do not collect SDP, ICE addresses, tokens, or pairing codes in public test reports.
External beta distribution requires a later approved TestFlight setup/review.
