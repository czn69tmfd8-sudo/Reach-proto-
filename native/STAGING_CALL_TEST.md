# Two-iPhone staging call check

Use the internal TestFlight build prepared for this call review on both iPhones.
Check the build number under REACH's menu > About REACH. Update in place so the
existing installation identities can be reused. Leave the existing pairing and
auth accounts intact. A simulator pass does not establish physical audio or video.

1. Open REACH on both phones and keep the app in the foreground. In **Pairing
   management**, tap **Refresh availability** on both. Record whether both
   report **Pairing verified**.
2. On one phone tap **Open my hand**. Allow camera and microphone access if
   prompted. On the other phone wait for the incoming hand, then explicitly tap
   **Take their hand** and respond to the permission prompts.
3. Check that each person sees the other's moving video and can hear and be
   heard. Confirm mute and camera-off work. Tap **End** and confirm media stops
   on both phones. Repeat with the other phone opening. Start on the same Wi-Fi,
   then repeat on separate networks. Direct/STUN connectivity can be blocked by
   restrictive NAT or firewalls. This candidate has no TURN relay.
4. If a step fails, open REACH's menu > **Connection information** > **Call
   troubleshooting** on both phones before force-quitting. Share only the build
   number, which phone opened or joined, network category, exact fixed error
   message, and the last few event labels and times. Crop away the home screen,
   photos, video, and pairing management. Never send a pairing code, UID,
   session ID, private logs, or credentials.

The label before failure separates partnership preflight, media preparation,
room registration, server room confirmation, and offer publication. Separate
failure labels identify the partnership listener, room listener, and signaling.
A server-denied room with verified home pairing can indicate a missing or
mismatched partner lock, different deployed rules, or another rejected room
write. The home status checks only the local lock and pair membership, while
the server requires both locks. That distinction does not justify changing a
lock. Live rule readback is a separate release check. Test actual revocation
with synthetic emulator partnerships only. Do not revoke the existing pairing
as a device test.
