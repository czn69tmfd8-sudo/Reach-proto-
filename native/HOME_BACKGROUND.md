# Original REACH home photograph

The default native background is the exact web asset `staging/Reach back.png`.
The web page references it at `index.html` in the `body:not(.reach-in-call)` style.
It entered repository history in commit `3af9dd4` (Add REACH sunset background).
The available repository history contains no larger original image.

- Original dimensions: **864 × 1536**; RGB PNG; **3,274,042 bytes**.
- SHA-256: `b1b72b03ca4f7d331daec329edf39c67136e7ae09daa180ac11b62a56a3f8efc`.
- Native copy: `REACH/Assets.xcassets/OriginalSunset.imageset/ReachSunset.png`.
- The copy is byte-for-byte identical. No screenshot extraction, resizing,
  re-encoding, generated image, or replacement photograph was used.

This is Byron and Aaron’s sentimental default image. Preserve it. If a higher
quality camera original is supplied later, review that exact file with the owner
before replacing it. Never substitute a similar image.

`ReachHomeBackground` is a presentation-only component. It fills the viewport
with the original image, clips to the screen bounds, and adds a separate subtle
readability overlay without editing the asset. The live staging home retains its
existing Form controls over translucent purple rows. The identity header supports
optional real profile images, shown above the photograph; empty profiles use
neutral, explicitly labelled placeholders. No personal profile images are stored
in the native app yet, and web profile data is not read or migrated.

`AppState.homeBackground` defaults to `.originalSunset`. A future picker can supply
`.couplePhoto(UIImage)` to the same renderer and reset to `.originalSunset` without
changing the home layout. Photo selection, persistence, sharing, removal and
privacy permissions are intentionally future work. Do not store photos in pairing
locks or change authorization rules to support this presentation preference.

The Demo tab and welcome artwork also reuse the original default. Demo remains
explicitly labelled as simulated. All live call actions, pairing operations,
revocation confirmation, media cleanup and permission requests remain unchanged.

Validation: the packaging test checks dimensions, SHA-256 and identity with the
web source. No new TestFlight build or upload is authorized by this change.
An actual iOS compile and visual device review remain pending; local packaging
checks are not a claim of a device-tested redesign.
