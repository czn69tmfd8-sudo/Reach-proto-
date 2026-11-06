# Firebase access options — authentication paused

The owner explicitly paused Google authentication. Do not start a login, change
rules, request credentials, or create service-account keys merely because this
file lists options. The approved rules deployment remains pending.

Supported alternatives for a later owner-selected attempt:

- Firebase CLI remote browser authorization (`--no-localhost`): the agent runs
  the technical command; the owner uses a browser on the phone. This is a
  supported remote-machine flow, but still requires Google authentication.
  Any authorization-code transfer needs a supported secure input mechanism;
  never ask the owner to paste codes/tokens into ordinary chat. Do not promise
  this will avoid Google's two-step requirements or work in the current client.
- Firebase Console in the owner's own phone browser: existing local sign-in or
  passkeys may be usable there. That browser does not authenticate the agent's
  cloud browser. The owner would need to supply the full current rules for
  baseline comparison and, after exact artifact verification, publish the
  approved complete additive source themselves. This is a manual fallback,
  not evidence that the agent can read the account or that anything is deployed.
- Official Firebase integration: if installed and authenticated, inspect its
  available capabilities before using it. Discovery previously showed it was
  not installed. Installation alone is not authentication or project access.

Do not weaken two-step verification, request broad new IAM access, or create
persistent private keys to work around a blocked browser login.

Deployment gates remain exact staging project ID, live-baseline comparison,
approved merged-source hash, rules activation verification and security checks.
Never substitute the native-only candidate for the complete additive artifact.

Official references:
https://firebase.google.com/docs/cli
https://firebase.google.com/docs/firestore/security/get-started
