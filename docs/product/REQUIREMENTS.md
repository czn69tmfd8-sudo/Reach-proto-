# REACH product requirements

Status: approved direction documented; coaching and shared-goal features are not implemented.
Immediate engineering milestone: the first verified, consent-based native audio/video call
between Byron's and Aaron's iPhones. Product planning must not delay that milestone.

## Purpose and scope

REACH helps two people connect intentionally and build a healthy relationship while
respecting each person's independent agency and private life. The product has three
core areas. It is not a relationship adjudicator or a substitute for professional care.
Existing web pairing records and functionality must be preserved. Native development
continues on native-reach; production, main, web data and billing remain untouched.

| Area | Purpose | Default visibility |
| --- | --- | --- |
| Our Connection | Secure audio/video communication and deliberately shared experiences | Authorized pair members, within each feature's explicit consent |
| My Private Coach | Individual reflection, message composition and communication guidance | Account owner only; pairing grants no access |
| Our Growth | Mutually agreed relationship goals, supported by independent Private Coaches | Only the goal fields and updates explicitly approved for sharing |

## 1. Our Connection

C1. Two separately authenticated installations can create and accept a fresh invitation,
persist authorization, revoke it and re-pair without migrating or altering web pairings.
Pair membership authorizes contact, not unrestricted camera/microphone access.

C2. The first native prototype requires an explicit foreground open/take action. Both
people grant system media permissions. End, revoked authorization, expiration and
terminal transport failure stop media. Ending while setup is pending must not allow
late callbacks to enable tracks. Mute/video choices during setup apply before sending.

C3. Offer, answer and ICE access is limited to the current authorized, unexpired room
and the correct participant role. Old callbacks, duplicate sessions and stale cleanup
must not alter a newer room. Reconnection must respect the original consent window;
a terminal session requires another explicit open/take action.

C4. Report actual transport state honestly. A simulated peer, SDP exchange, successful
build, or connected indicator alone does not establish a verified two-phone call.
Physical acceptance requires moving video and intelligible sound in both directions.
Direct/STUN is currently implemented; TURN and separate-network reliability remain
unverified. Never promise universal cellular/NAT connectivity before testing it.

C5. Shared experiences may later include memories, prompts and intentional time
together. Existing web functionality remains supported; equivalent native features
are separate roadmap work, not assumed complete.

C6. The longer-term open-hand/quiet connection concept requires a separately reviewed,
time-bounded advance-consent design and platform feasibility assessment. It does not
authorize silent, background or overnight joining in the current prototype.

## 2. My Private Coach

P1. Provide an individually controlled space for reflection, sorting through feelings,
composing messages, rehearsing conversations and considering communication options.
The user decides whether to act, send, edit or discard. No automatic partner messages.

P2. Encourage empathy, accountability, curiosity, self-reflection, personal agency and
healthy communication. Acknowledge uncertainty and distinguish observations from
interpretations. Offer questions and alternatives rather than verdicts about people.
Do not diagnose emotions or mental-health conditions, claim certainty about a partner's
intentions, assign blame or compatibility scores, or make relationship decisions.
Respect safety concerns without pressuring reconciliation or continued contact.

P3. Conversations, drafts, reflections, preferences, reminders, observations and any
inferred personalization remain private to their owner. A partner cannot read them,
query their existence, receive summaries, or learn coach usage/activity through shared
screens, notifications, analytics, exports or generated text. No partner-facing
sentiment, risk, engagement, trust or relationship-health scores.

P4. Start with user-supplied context and explicit questions. Importing messages, using
saved reflections, retaining memory, or adapting assistance each requires its own
clearly explained, optional consent. Declining any option must preserve basic private
reflection and core communication functionality. No blanket consent through pairing.

P5. Reminders are user-created or explicitly accepted suggestions. Users control
purpose, schedule, channel, quiet hours and notification preview visibility. Support
editing, snoozing and disabling. No guilt-based nudges, partner monitoring, shared
usage streaks, or disclosure that the other person is using the coach.

P6. Optional adaptive assistance must expose what context is saved, allow correction
and deletion, and provide an immediate off switch. Turning it off stops future use;
removing source context must remove/invalidate dependent memories and derived
observations according to the published deletion policy. Do not infer partner facts
from private signals or silently expand a grant to a new source or modality.

P7. Voice transcription, emotion/prosody interpretation and passive sensing are
exploratory only. No current permission request, capture, background analysis, model
integration or implementation is authorized by this document. Any future proposal
needs separate feasibility, privacy, safety and explicit-consent review. Never analyze
a partner's call media on the basis of only one person's coach consent.

## 3. Our Growth

G1. Either person may propose a relationship goal. Both must accept its exact shared
content and visibility before it becomes a mutual goal. Material edits require renewed
agreement; a pending proposal must not be displayed as a mutual commitment.

G2. Each partner's independent coach may help that person choose private actions in
support of an accepted shared goal. Only the accepted goal is shared context. Private
plans, reflections, completion evidence, coaching suggestions and inferred progress
remain private unless their owner deliberately shares a specific previewed update.

G3. Shared progress is explicit self-report, not surveillance or automatic assessment.
Distinguish individual updates from mutually agreed outcomes. Do not rank partners,
automatically mark the other person's effort, reveal private reminders, or infer
success/failure from app use, messages, calls, coach sessions or mood estimates.

G4. Users can decline a goal, pause their own participation, withdraw sharing or leave
a pairing without losing access to their own private coach. Goal history must describe
consent changes neutrally and must not disclose a private reason or generated analysis.

## Non-negotiable release gates

- Complete the physical-call acceptance plan before expanding native product scope.
- Enforce owner-only private-data access and active-pair shared access on the server,
  not just by hiding UI. Private coach authorization must not depend on pair membership.
- Run negative tests for cross-user access, revoked grants, stale/offline jobs, sharing
  previews, re-pairing, exports, notification leakage and derived-memory deletion.
- Define data retention, deletion, recovery, provider processing and operational access
  before private coaching persistence or AI requests are enabled.
- No call recording, transcript generation, inferred emotion, shared private summaries,
  external message sending, billing or publishing is implemented by this planning work.

See [privacy and architecture](PRIVACY_AND_ARCHITECTURE.md),
[roadmap](ROADMAP.md), and the [two-iPhone acceptance plan](../../native/TWO_IPHONE_TEST_PLAN.md).
