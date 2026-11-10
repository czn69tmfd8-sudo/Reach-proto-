#!/usr/bin/env python3
"""Fail fast if a historical regression baseline is missing from checkout.

Run after fetching full Git history. Never substitute HEAD or silently skip
historical comparisons.
"""
import subprocess
import sys

BASELINES = {
    "e7591c7c3ebd4c73c35a606de019859df60f9f48": [
        "native/firebase/firestore.rules",
        "native/firebase/reviews/staging-2026-11-06-hardened/merged.rules",
        "native/REACH/Firebase/ReachEnvironment.swift",
        "native/REACH/Models/PairingAuthorization.swift",
        "native/REACH/Models/ReachHomeAvailability.swift",
        "native/REACH/Media/NativeWebRTCPeer.swift",
        "native/REACH/Media/ReachTransportWatchdog.swift",
        "native/REACH/Services/PermissionService.swift",
        "native/project.yml",
    ],
    "641cc0debc41f3e60517ab1880d8444ab9c5dc94": [
        "firebase.json", ".firebaserc", "index.html", "staging",
        "native/firebase/firestore.rules", "native/firebase/firebase.json",
        "native/REACH/Firebase/FirebaseBootstrap.swift",
        "native/REACH/Firebase/FirebaseDependencyFactory.swift",
        "native/REACH/Firebase/FirebaseAuthProvider.swift",
        "native/REACH/Services/LocalRelationshipFile.swift",
        "native/REACH/Services/RelationshipJournalStore.swift",
        "native/REACH/Models/RelationshipJournal.swift",
        "codemagic.yaml",
    ],
}

def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True)

def main():
    failures = []
    for commit, paths in BASELINES.items():
        result = git("cat-file", "-e", commit + "^{commit}")
        if result.returncode:
            failures.append(f"MISSING COMMIT {commit}: {result.stderr.strip()}")
            continue
        for path in paths:
            result = git("cat-file", "-e", f"{commit}:{path}")
            if result.returncode:
                failures.append(f"MISSING BASELINE PATH {commit}:{path}: {result.stderr.strip()}")
    if failures:
        print("HISTORICAL BASELINE PREFLIGHT FAILED", file=sys.stderr)
        print("\n".join(failures), file=sys.stderr)
        return 1
    print("Historical baseline preflight passed: both commits and all 22 protected paths exist")
    return 0

if __name__ == "__main__":
    sys.exit(main())
