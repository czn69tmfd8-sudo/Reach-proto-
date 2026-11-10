#!/usr/bin/env python3
"""Apply a strict, local-only Adventure Book preview overlay to a CI checkout.

This script never deploys Firebase, signs an app, uploads, or changes another branch.
The preview app needs its OWN registered Firebase iOS application and Apple App ID.
"""
import argparse
import base64
import os
from pathlib import Path
import plistlib

PROJECT = "reach-staging-a4745"
ORIGINAL = "com.reachprototype.app"
PREVIEW = "com.reachprototype.adventurepreview"
BUCKET = "reach-staging-a4745.firebasestorage.app"
APP_NAME = "REACH Book Preview"
ENTITLEMENTS = "Configuration/AdventurePreviewSimulator.entitlements"

def replace_exact(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise ValueError(f"Unexpected source layout in {path}; refusing overlay")
    path.write_text(source.replace(old, new))

def prepare(root):
    root = Path(root)
    project = root / "project.yml"
    environment = root / "REACH/Firebase/ReachEnvironment.swift"
    replace_exact(project, "PRODUCT_BUNDLE_IDENTIFIER: " + ORIGINAL,
                  "PRODUCT_BUNDLE_IDENTIFIER: " + PREVIEW)
    replace_exact(project, "INFOPLIST_KEY_CFBundleDisplayName: REACH Staging",
                  'INFOPLIST_KEY_CFBundleDisplayName: "REACH Book Preview"')
    replace_exact(project,
                  '"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]": Configuration/Simulator.entitlements',
                  '"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]": ' + ENTITLEMENTS)
    replace_exact(environment,
                  'guard configuredBundleID == nativeBundleID, runningBundleID == nativeBundleID else {',
                  'guard configuredBundleID == runningBundleID,\n'
                  '              [nativeBundleID, "' + PREVIEW + '"].contains(runningBundleID ?? "") else {')
    plist = {
        "application-identifier": "REACHSIM00." + PREVIEW,
        "keychain-access-groups": ["REACHSIM00." + PREVIEW],
        "get-task-allow": True,
    }
    target = root / ENTITLEMENTS
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(plistlib.dumps(plist))
    return target

def install_preview_config(encoded, destination):
    if not encoded:
        raise ValueError("Dedicated preview Firebase iOS app configuration required.")
    try:
        config = plistlib.loads(base64.b64decode(encoded, validate=True))
    except Exception:
        raise ValueError("Invalid preview Firebase plist.") from None
    if config.get("PROJECT_ID") != PROJECT or config.get("BUNDLE_ID") != PREVIEW:
        raise ValueError("Preview Firebase app must use the staging project and unique preview bundle ID.")
    if config.get("STORAGE_BUCKET") != BUCKET:
        raise ValueError("Preview Firebase app must reference the verified staging Storage bucket.")
    for key in ("GOOGLE_APP_ID", "API_KEY", "GCM_SENDER_ID"):
        if not isinstance(config.get(key), str) or not config[key]:
            raise ValueError(f"Preview Firebase app missing {key}.")
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with os.fdopen(os.open(destination, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600), "wb") as file:
        file.write(base64.b64decode(encoded, validate=True))
    destination.chmod(0o600)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="native")
    parser.add_argument("--install-config", action="store_true")
    args = parser.parse_args()
    prepare(args.root)
    if args.install_config:
        install_preview_config(
            os.environ.get("REACH_ADVENTURE_PREVIEW_FIREBASE_PLIST_BASE64"),
            Path(args.root) / "REACH/GoogleService-Info.plist")
    print("Isolated Adventure Book preview overlay prepared; no signing or deployment.")

if __name__ == "__main__":
    main()
