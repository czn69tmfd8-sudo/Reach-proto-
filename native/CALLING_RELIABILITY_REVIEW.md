# Native calling review for the next sprint

Baseline: e7591c7, approved prior app source 8e41fb3. No pairing, authentication,
Firestore signaling, SDK media setup or consent policy has been relaxed.

- Pair codes expire after 30 minutes before acceptance. An expired invitation is
  explicitly revoked through pairing management before a fresh code is created.
  Re-pairing preserves the authenticated UID and only replaces a revoked native lock.
  No automatic identity reset, account merge or bypass has been added.
- Home availability is a server-backed read, refreshed every five seconds and
  treated as stale after fifteen seconds or room expiry. Every call action still
  independently authorizes before media/session setup. Paired is not online.
- Permissions still require explicit open/take and use system camera/microphone
  prompts. Denied permissions have app Settings guidance in connection information.
- End, background and leaving the call view close local tracks; revocation stops
  local media before awaiting server cleanup. Generation guards reject late callbacks.
  Pair and room listeners and room-expiry task are retained unchanged.
- Negotiation timeout remains 45 seconds and interruption timeout 20 seconds.
  A fresh explicit hand is required after terminal failure; no automatic rejoin.
- This sprint adds bounded, in-memory event labels/times for the latest 20 events,
  safe SDK-error copy, and a troubleshooting sheet. No UID/pair code, SDP, ICE
  addresses, TURN credentials, media content or analytics are collected/exported.
- Cleanup failure now reports that media stopped but server cleanup is unconfirmed,
  without exposing raw remote error payloads. No change to cleanup sequencing.

## TURN before promising network reliability

The active RTC configuration is STILL STUN-only. `ReachRelayGrant` is an unconnected
input validator for a future authenticated staging credential broker. No server,
relay account, credential, billing or network setting was created or activated.

Before implementation: choose a provider/region and budget with the owner; approve
an authenticated broker that checks the current non-revoked pair and both locks;
issue <=10-minute single-session credentials; support UDP 3478 and TLS/TCP 443;
keep secrets server-side, omit credentials from all logs, rate limit issuance,
reject expired grants and enforce transport/server allowlists. Do not bundle static
TURN secrets. Test relay-only and normal ICE with consent/timeout/revocation active.
The draft grant validator alone is not authorization or sufficient endpoint policy.

## Required physical-device matrix

Two actual iPhones: Wi-Fi/Wi-Fi, Wi-Fi/cellular, cellular/cellular and restrictive
networks after TURN approval. Explicitly open/take; verify both directions of audio
and video, mute/camera, denied permissions and return from Settings; End on each
side; revocation mid-call and while offline; background/foreground; stale room and
expired invite recovery; force-close and relaunch. Verify no capture survives End
or revocation, no stale room is reused and no transition is labelled live before
transport connects. Media transport connected still does not prove audible sound
or visible remote frames. No genuine two-device call is claimed by this review.
