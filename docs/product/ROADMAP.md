# REACH phased roadmap

This roadmap separates implemented code, verified behavior and planned capabilities.
The three-area vision is a design direction, not a claim of delivered coaching.
No coaching implementation begins in this development session.

## Phase 0 — First verified two-iPhone connection (immediate)

Existing implementation: native Firebase staging adapters; fresh pairing, revocation
and re-pairing; role-bound offer/answer/ICE; actual WebRTC tracks and device camera
code; foreground consent and media cleanup; bounded ICE queues and interruption
handling. Existing web pairings and functionality remain untouched.

Evidence at recovery: Codemagic #11 passed on 1c60ac1 per owner; GitHub's full portable
suite passed 112/112 on adfec0c. Bluetooth SDK compatibility code is committed. The
newer macOS build exposed an ICE-publication Sendable error, now being fixed and
revalidated. These results do not prove physical capture, pairing or a live phone call.

Next gates, in order:

1. Complete macOS simulator build, installation/launch and native tests on the current
   branch; compile physical-device code without signing. Preserve actionable logs.
2. Keep Firebase authentication and deployment paused. Only after that pause is lifted
   and supported authentication is available, verify the live staging rules baseline
   and exact approved additive artifact. Stop on any difference; never replace web
   rules wholesale or deploy to production.
3. Apple enrollment is already paid and awaiting activation. Prepare Team/App IDs,
   both phone UDIDs, signing identities and protected Codemagic storage. No purchase,
   publishing or TestFlight upload is authorized. Follow DEVICE_INSTALLATION.md.
4. Produce and verify a signed staging install for both phones. Verify independent
   native SDK identities, fresh pairing persistence and revocation against staging.
5. Complete the two-iPhone acceptance plan: actual moving video and intelligible sound
   both ways; setup privacy choices; End/background/expiry/revocation; role swapping;
   interruption and explicit retry. Record the exact build and scenario outcomes.
6. Test separate networks. If direct/STUN cannot traverse them, evaluate TURN options
   and credential handling. Obtain approval before purchases or billing changes.

Exit evidence: a documented real two-device call plus consent/revocation/cleanup
checks. No simulated connection or successful compilation may substitute.

## Phase 1 — Connection reliability and deliberate shared experiences

Use real-device findings to harden camera/audio routes, interruptions, ICE/network
behavior, accessible controls and clear error/retry flows. Add TURN only after its
service/security requirements are resolved. Prepare a separately approved TestFlight
workflow when membership, signing and distribution access are available. Preserve
current web compatibility. Plan native memories/prompts independently of coach data.

Do not add quiet/overnight joining until advance-consent scope, expiry, revocation,
platform/background limitations and both partners' experience have been reviewed.

Exit gate: repeatable foreground calls across agreed networks/device versions;
privacy-preserving diagnostics; approved installation/testing route.

## Phase 2 — Private Coach foundations (future, gated)

Before feature implementation, decide account recovery/migration, persistence and
retention, processing mode, provider terms if any, deletion behavior and operational
access. Threat-model owner-only isolation, processor visibility, device caches,
notifications and any future AI tools. Specify consent and data models; test their
server enforcement before enabling content collection or inference.

Begin with owner-entered reflection, message drafting and communication guidance,
with user-controlled save/delete and no automatic partner sharing or message sending.
Keep the initial context small and explicit. Coaching should support agency, empathy
and accountability without diagnosis, mind-reading or relationship verdicts.

Exit gate: reviewed privacy model, access-control and deletion tests, transparent
processing disclosures and owner-controlled context. No inferred partner profiles.

## Phase 3 — Optional reminders and adaptive assistance (future)

Add editable reminders, quiet hours and safe previews with independent channel/OS
permissions. Optional saved memory and adaptive help require separate revocable
consent, visible source context, correction/deletion and grant-checked jobs. Default
to off for ongoing personalization, message imports and proactive processing.

Exit gate: revoked/expired consent stops future jobs and delivery; deleted context
cannot reappear through derived memory; no partner-visible usage or pressure loops.

## Phase 4 — Our Growth (future)

Introduce explicit goal proposals, independent acceptance of exact versions and
clear neutral withdrawal. Each private coach may help its owner with an accepted
shared goal; neither can access the other's plans or reflections. Implement a
preview-and-confirm workflow for specific voluntarily shared updates. Keep progress
self-reported; do not infer it from calls, coach use, emotion or private behavior.

Exit gate: two-user isolation tests, mutual-version acceptance, deliberate sharing,
re-pairing/revocation, stale-job and notification/export leakage tests all pass.

## Phase 5 — Exploratory research only

Assess optional voice interfaces separately from any emotion/prosody interpretation.
No passive listening, call analysis, recording or emotional inference is planned for
initial release. Research must address uncertain interpretation, bias, multilingual
and accessibility limitations, privacy and separate consent from every person whose
media could be processed. Do not label speculative emotion estimates as facts.

Proceed only after explicit scope and privacy/safety decisions. Research is not
permission to collect data, request microphone access or ship an analysis feature.

## Current external dependencies

| Dependency | Current state | Next allowed step |
| --- | --- | --- |
| macOS validation | Build #11 known good; newer branch requires current SDK results | Use configured CI; fix verified failures without duplicate manual reruns |
| Firebase account access/deployment | Paused by owner | No login or deployment; later compare authenticated baseline and approved artifact |
| Apple Developer membership | Paid, activation pending | Prepare signing; wait for activation before account-dependent operations |
| Physical two-iPhone runtime | Not verified; no signed install evidence | Follow staged acceptance gates after signing and staging access are ready |
| Coach/AI services and data architecture | Planning only | Resolve privacy/consent/storage decisions after immediate call milestone; no implementation now |

References: [requirements](REQUIREMENTS.md), [privacy and architecture](PRIVACY_AND_ARCHITECTURE.md),
[installation](../../native/DEVICE_INSTALLATION.md), and
[first-call checklist](../../native/TWO_IPHONE_TEST_PLAN.md).
