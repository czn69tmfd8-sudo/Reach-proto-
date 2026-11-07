# Native REACH sprint handoff

Branch: `native-reach`. Recoverable release baseline:
`e7591c7c3ebd4c73c35a606de019859df60f9f48`, with prior approved application source
`8e41fb3f24263cc5c4ea1dec6a82b58270285c76`. Both remain in remote history; no force
push, main change, public web change, Firebase deployment or account/billing change.
This sprint intentionally changes native application source under the new development
instruction. It has not been approved or validated for distribution.

## Implemented app features

`f00c2bdca6bc2ac81224882ac4fa84aba017c2a4`:

- Keyboard observation dismisses on outside taps without cancelling controls or text
  input taps; shared page/editor scroll views dismiss interactively; Done and return
  controls dismiss input. Observers detach when their view leaves the window.
- Top-left Reach menu presents pairing management, connection information, privacy,
  security and version information in dismissible sheets. Pairing actions and status
  still use the original backend and authorization checks. Essential hand actions
  and current availability remain on Reach; technical cards leave the default view.
- Portrait container removed; larger circular portraits and connecting heart remain
  the focus. Panels use more translucent material/purple tint with opaque treatment
  for Reduce Transparency. Standard safe areas/TabView and scroll keyboard avoidance
  are retained; no keyboard safe-area override or custom floating tab bar added.
- Together: create/edit/delete dated memories with optional selected photographs;
  deterministic daily prompts with private responses; browse/save/categorize/search
  date ideas and mark planned/completed; save/dismiss daily in-app reminders. Empty
  states, error feedback, editing sheets and destructive-delete confirmations work
  against local storage. Suggestions are labelled, not manufactured user activity.
- Us retains custom names/profile photos/background/optional personal words and adds
  editable/deletable relationship milestones. No personal names, dates or faith
  message is hardcoded. Photos/names never grant pairing authorization.
- Journal save publishes state only after a successful atomic write. Complete file
  protection on iOS, backup exclusion, schema/version checks, unique IDs, 200-entry
  and 8-MB-photo budgets, bounded fields and explicit load failure prevent silent
  resets or overwrites. Memory imports downsample/reencode selected images, remove
  original metadata and retain at most 1 MB each (12 MB input maximum).
- Calling adds bounded in-memory event labels/times, a troubleshooting sheet and
  safe error copy. Raw remote payloads, SDP, ICE addresses and credentials are not
  displayed/exported. Cleanup failure accurately distinguishes stopped local media
  from unconfirmed server cleanup. Pairing/signaling/permission/timeout/media-stop
  policies are unchanged. TURN grants are an unconnected proposal validator only.

These are functional UI/persistence implementations, not static mockups. Their new
Swift code still needs compilation and execution. No claim of physical iPhone UI
validation or genuine two-device audio/video verification is made. Appearance and
journal content are explicitly labelled PRIVATE ON THIS IPHONE; they are not
synchronized, do not notify a partner and are lost when app data is deleted. Saved
reminders are in-app records, not scheduled push/local notifications. Selected
memory photos are in the protected journal; the default sunset asset is never
reencoded or replaced. The simulated demo stays explicitly labelled in Together.

## Synchronization preparation only

`9b28a69a641c9e1ec0bffc399782bdbb7a36f2c3` adds a text-only, authored content model,
exact-snapshot consent policy, standalone review-only rules and emulator scenarios.
There is no Firestore writer, shared photo service, sharing UI or enabled sync.
See `sync-proposal/README.md` for full schema, owner/deletion/revocation constraints,
cache and retention gaps and activation blockers. Do not deploy the standalone
proposal. Actual rules compilation/evaluation is pending; syntax-checking JavaScript
does not validate rules. Live rules remain byte-identical to the baseline.

## Verification completed in this environment

- 47 Python regression checks pass, including four new boundary checks for release
  security/media identity, local content/backend separation, non-deployed proposal
  isolation and validation-only workflow restrictions.
- Nine offline web recovery/regression tests pass.
- All repository native/firebase and staging JavaScript test sources pass Node syntax
  checking; all native Python scripts compile; YAML parses and every workflow script
  passes bash syntax checking. Existing workflows compare equal to e7591c7.
- Changed Swift files parse with tree-sitter without new syntax errors. Some unchanged
  Swift 6 constructs exceed that parser's grammar; it is not a compiler/type checker.
- 32 XCTest methods added: journal model 8, file persistence 3, iOS store/resources 6,
  sharing policy 6, call review 3, UIKit behavior 6. Total declared native tests: 163. These have NOT
  executed here. UIKit behavior tests cover input hit-testing, observer cleanup
  and sanitized errors; actual keyboard interaction still needs simulator/device UI checks. Portable runner exits explicitly: `swiftc is required; this script
  does not install a toolchain.` Xcode, iOS SDK and simulator are unavailable here.
- Seven proposed-rules emulator scenarios added, not executed. The prior automatic
  approval review blocked possible external Firebase access; no emulator retry or
  bypass was attempted. No updated security-suite pass is claimed.
- Original sunset SHA-256:
  `b1b72b03ca4f7d331daec329edf39c67136e7ae09daa180ac11b62a56a3f8efc`.
- Published merged-rules artifact SHA-256 remains
  `7e62b5e95f939d56155ce047634ead33023dfd1e6b35a6e20cb3601c7ddc00b8`.

The previous successful run of 131 native tests applies to the release baseline;
it is not evidence that the additional 32 tests or new UI pass.

## Next authorized action requires owner approval

No build was started. A new manual workflow is prepared:

- ID: `reach-ios-sprint-validation`
- Name: `REACH next sprint validation only (manual, no upload)`
- Branch: `native-reach`, choose the final sprint commit containing this document.
- No Firebase variable group/plist, signing integration, emulator, publishing or
  automatic trigger. It runs offline checks and portable Swift tests, all native
  XCTest, simulator resource/launch checks and unsigned physical-iPhone compilation.
- Artifacts: test summary/xcresult, source commit/app tree, simulator screenshot and
  device build log. Launch explicitly terminates the unit-test host before capturing
  the UI after a short render interval; inspect the actual rendered screenshot.

Existing validation workflow remains pinned to 8e41fb3 for historical reproducibility.
Existing TestFlight archive remains pinned to that approved source/build 2 and will
reject this sprint's app/test changes before staging configuration installation.
Do not run that archive for the new sprint. A later release review must approve the
new application source and an unused build number before updating the release pin.

After approved macOS validation, inspect all 163 test results and any compiler
warnings/errors. Verify keyboard dismissal/focus, menu and End/revoke behavior while
sheets are presented, photo import/cancel/reset, corrupt/full local storage, journal
CRUD/search/daily rollover, narrow iPhones, large Dynamic Type, VoiceOver, Reduce
Motion/Transparency and all three tabs on actual iPhones. Visual contrast, keyboard
interaction and performance are not proven by syntax/unit tests. Run the complete
emulator/security suite only in an approved isolated environment before approving
any shared-data activation. TURN provider/broker/credentials, shared-photo Storage,
shared cache revocation/retention, future TestFlight upload and deployment each
remain separate approval decisions. See CALLING_RELIABILITY_REVIEW.md for the
physical call/network test matrix.
