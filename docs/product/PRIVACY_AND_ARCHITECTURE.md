# REACH privacy, consent and architecture requirements

Design specification only. Proposed coach/goal components and data paths below do
not exist in the app or deployed Firestore rules. No deployment is authorized here.

## Trust boundaries

Pairing permits defined Our Connection and Our Growth operations. It never grants
access to My Private Coach. Private authorization is owner identity plus a valid,
purpose-specific grant when processing is optional. Shared authorization is a separate
check for both current members, the exact accepted shared object/version and scope.

Private from a partner is not the same as inaccessible to an AI processor or service
operator. Cloud AI would receive the specifically selected plaintext context it must
process. Do not claim end-to-end confidentiality from that processor. Any on-device
mode, end-to-end encryption design, cloud provider, retention term or recovery method
must be selected and verified before implementation. Existing WebRTC media protection
does not make Firebase signaling metadata or future coach storage end-to-end encrypted.

## Consent model

Consent is opt-in, understandable, granular, time-bounded where appropriate, and
revocable. Pairing acceptance and OS microphone/camera permissions are not coach
processing consent. Absence, expiration, ambiguity or stale versions means deny.

| Capability | Required authority | Revocation behavior |
| --- | --- | --- |
| Pairing | Fresh invitation accepted by the second authenticated user | Deny future pair operations; stop media/signaling; invalidate pair-scoped work |
| Live call | Authorized pair plus explicit current open/take and OS media permission | Stop local media immediately; server denies expired/revoked signaling |
| Private reflection/drafts | Owner identity; persistence choice explained | Owner can delete; no partner grant exists |
| Cloud coach response | Owner's explicit purpose and selected context under disclosed processing terms | Stop new dispatch; discard unauthorized late output; disclose limits of already-sent processing |
| Saved memory/personalization | Separate opt-in per context source and retention purpose | Stop use and invalidate derived context, indexes and queued work |
| Reminders/notifications | Owner-approved schedule/channel plus OS permission if needed | Cancel future scheduling and server jobs; avoid sensitive lock-screen content by default |
| Use a shared goal in private coaching | Owner opts to use an active mutually accepted goal | Stop future retrieval when membership/goal access ends; do not import private partner data |
| Share a specific update or draft | Owner previews exact content, recipient, destination and version, then confirms | Deny future delivery/use under the grant; offer supported removal of shared copy |
| Advanced voice/emotion analysis | No current grant or feature; separate future review | No collection, implementation or inference in current phases |

A proposed grant record contains owner, purpose, allowed source IDs/versions,
destination/processor, permitted operations, creation/expiry, consent version and
revocation state. Do not store reflection content in consent audit records. Record
only the minimum metadata needed to enforce and demonstrate the user's choice.
An organization-wide setting or pair agreement cannot override individual refusal.

At every read, generation, scheduled job and share operation, revalidate identity,
active grants and source versions. A cached consent flag or token is insufficient.
Bind work to account, pair generation and grant version. Reject late results after
logout, revocation, deletion, expiry or re-pairing. No automatic retry after consent
is withdrawn; an uncertain write must not be presented as confirmed sharing.

## Deliberate sharing

1. The owner selects a private draft or composes an update. Suggestions stay private.
2. Show a preview of the exact material to be sent, the named current partner, the
   destination and visibility. Highlight included private content; never silently
   attach chat history, observations, memories, source citations or inferred context.
3. Require a fresh explicit send/share confirmation for that version and recipient.
   Approval of a previous draft does not authorize later generated revisions.
4. Recheck membership, revocation and grant version server-side before committing.
   Make retries idempotent so uncertain responses do not create duplicate disclosures.
5. Record a receipt containing minimal identifiers/version and delivery status.
   Do not send external email, SMS or social messages without a separate user action.

A mutual goal proposal is deliberately shared to the chosen partner, but becomes an
accepted joint goal only after both accept its shared content. A coach conversation
cannot become a shared goal through automatic extraction or summarization.

Revocation cannot erase information already read, screenshotted, exported, delivered
in a notification, or sent to a processor. Explain those limits plainly. Withdraw
future access and processing promptly; provide deletion/removal controls without
promising to retract copies outside REACH's control.

## Proposed component and data boundaries

| Component | Responsibility | Prohibited access/behavior |
| --- | --- | --- |
| Native Connection coordinator | Pair lifecycle, room identity, consent, SDP/ICE, media shutdown | No forwarding media, ICE, call content or presence into coaching |
| Private Coach interface | Owner-only reflections, drafts and transparent context selection | No partner inbox, cross-account search or automatic shared summaries |
| Private context store | Owner-scoped content, saved preferences and derived memory | No pair-based ACL, shared collection group query or partner cache |
| Consent/policy service | Validate actor, scope, source/version, purpose, expiry and destination | No inference of consent from relationship status or prior app use |
| AI gateway, if later selected | Minimize authorized context; enforce limits; check before dispatch and delivery | No raw client keys, unfiltered database access, model-controlled ACLs or tool sends |
| Growth service | Proposals, exact versions, independent acceptances and explicit shared updates | No read capability for either person's private coach store |
| Reminder scheduler | Owner-selected timing, local scheduling preferred, grant-checked cloud jobs if needed | No partner activity disclosure, private text in logs or default lock-screen previews |
| Operational telemetry | Minimal errors/performance and consent receipts | No prompts, drafts, transcripts, SDP/ICE, pairing codes or personal-content analytics |

Illustrative future storage separation: owner-private coach records under an
identity-scoped namespace; shared goals under an independently authorized pair-scoped
namespace. Exact schemas are unresolved. Do not append these concepts to existing
web pairInvites, memberLocks or rooms, or reuse nativeStaging/v1 signaling access as
coach authorization. Native Connection's current tested schema remains unchanged.

A shared goal's public-to-the-pair fields might include its title, agreed wording,
version, status and the two acceptances. The shared representation must contain no
private coach IDs, source pointers, derived observations or private task completion.
A per-user private plan can reference an accepted goal but is never reverse-queryable
by the partner. A share is an explicit minimized copy, not a live pointer granting
access to private source data.

Server SDKs can bypass Firestore rules. Any future backend/AI gateway must enforce
owner and grant checks itself and use least-privilege service identities. Separate
private/shared APIs and serialization types; do not rely on model instructions or
client UI filtering for privacy. Treat user/partner text as untrusted input, never
as authority to query data or call tools. Models cannot expand a consent grant.

## Retention, account changes and operations

- Choose and disclose retention for content, derived memory, job payloads, audit data,
  backups and processor copies before collection. Do not silently invent indefinite
  retention. Let users inspect/delete saved context and understand recovery limits.
- Deleting a source must invalidate associated embeddings, summaries, cached context
  and pending jobs; deletion of originals alone is insufficient. Document any bounded
  backup retention and restoration suppression for already-deleted records.
- Unpairing withdraws future shared access and pair-scoped jobs. Each user retains
  independent ownership of their private coach. Never transfer it to a new partner.
- Logout/account switching must isolate or clear local private caches and notification
  bindings. Anonymous-auth recovery and verified account migration need a reviewed
  ownership design before launching persistent private coaching.
- Default private-content export includes only the owner's authorized selections.
  Shared exports require explicit scope. Do not include partner-private material or
  content inferred by an assistant as though it were a partner's factual statement.
- Use transport protection, encryption at rest and protected device storage. Confirm
  actual guarantees before making marketing claims. Prefer no operational access to
  content; any necessary exception must be narrowly authorized, audited and disclosed.
- Provider selection requires review of training use, retention/deletion, region,
  subprocessors, access controls and incident handling. No provider is selected or
  external credentials requested by this document.

## Privacy acceptance scenarios for future implementation

Test direct IDs and list queries as another user, unpaired user and newly paired
partner; all private reads/writes and usage metadata must be denied. Test backend
handlers as well as Firestore rules. Test shared-goal edits without both acceptances,
replayed share approvals, wrong-recipient retries, offline/stale jobs and revocation
during inference. Test deleted-memory regeneration, cache/account switching,
notification previews, crash reports, exports and support tooling for leakage.

With two independent coach sessions, assert that neither output can include the
other's private material even when both discuss the same shared goal. Model responses
must not reveal whether the partner has ever used coaching. Use adversarial content
asking for partner data to verify that authorization remains outside the model.
