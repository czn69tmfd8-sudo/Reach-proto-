#!/usr/bin/env python3
"""Upload ONLY the previously produced REACH Build 16 IPA; never build or distribute."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

EXPECTED = {
    "CM_BRANCH": "release/adventure-book-archive-preparation",
    "REACH_APPLE_TEAM_ID": "GFUK853ZT5",
    "REACH_IOS_BUILD_NUMBER": "16",
    "REACH_UPLOAD_AUTHORIZATION": "UPLOAD_EXISTING_BUILD_16_ONLY",
}
REQUIRED = ("CM_API_TOKEN", "REACH_ORIGINAL_ARTIFACT_URL", "REACH_ORIGINAL_IPA_SHA256",
            "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER",
            "APP_STORE_CONNECT_PRIVATE_KEY", "APP_STORE_APPLE_ID")
TARGET = Path("build/reach-build16-original/REACH.ipa")


def preflight():
    for key, value in EXPECTED.items():
        if os.environ.get(key) != value:
            raise ValueError("Incorrect upload authorization or release identity: " + key)
    if os.environ.get("CM_PULL_REQUEST_DEST"):
        raise ValueError("Pull request builds cannot upload.")
    missing = [k for k in REQUIRED if not os.environ.get(k, "").strip()]
    if missing:
        raise ValueError("Required secure inputs unavailable: " + ", ".join(missing))
    digest = os.environ["REACH_ORIGINAL_IPA_SHA256"].lower()
    if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
        raise ValueError("An independently recorded original IPA SHA-256 is required.")
    parsed = urllib.parse.urlparse(os.environ["REACH_ORIGINAL_ARTIFACT_URL"])
    if parsed.scheme != "https" or parsed.hostname != "api.codemagic.io" or not parsed.path.startswith("/artifacts/"):
        raise ValueError("Original artifact URL must be an HTTPS Codemagic Artifacts API URL.")
    if not parsed.path.endswith("/REACH.ipa"):
        raise ValueError("The source must be the original REACH.ipa.")
    return parsed.geturl()


def retrieve():
    """Use Codemagic's documented /public-url exchange, with a 120-second expiry."""
    import time
    url = preflight()
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    if TARGET.exists():
        raise ValueError("Original artifact destination already exists.")
    payload = json.dumps({"expiresAt": int(time.time()) + 120}).encode()
    request = urllib.request.Request(
        url + "/public-url", data=payload,
        headers={"x-auth-token": os.environ["CM_API_TOKEN"],
                 "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)
    temporary_url = data.get("url")
    parsed = urllib.parse.urlparse(temporary_url or "")
    if parsed.scheme != "https" or parsed.hostname != "api.codemagic.io":
        raise ValueError("Codemagic returned an unexpected temporary download URL.")
    digest = hashlib.sha256()
    size = 0
    try:
        with urllib.request.urlopen(temporary_url, timeout=120) as response, TARGET.open("xb") as output:
            if response.status != 200:
                raise ValueError("Artifact download failed.")
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > 100 * 1024 * 1024:
                    raise ValueError("Unexpectedly large IPA.")
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != os.environ["REACH_ORIGINAL_IPA_SHA256"].lower():
            raise ValueError("IPA SHA-256 mismatch; no upload permitted.")
        with zipfile.ZipFile(TARGET) as z:
            infos = [n for n in z.namelist() if n.startswith("Payload/") and n.endswith(".app/Info.plist") and n.count("/") == 2]
            if len(infos) != 1:
                raise ValueError("Expected exactly one iOS application Info.plist.")
            info = plistlib.loads(z.read(infos[0]))
            if (info.get("CFBundleIdentifier"), info.get("CFBundleShortVersionString"), str(info.get("CFBundleVersion"))) != ("com.reachprototype.app", "0.1.0", "16"):
                raise ValueError("IPA bundle or version does not match approved Build 16.")
        print("Original IPA downloaded and verified; bytes:", size)
    except Exception:
        TARGET.unlink(missing_ok=True)
        raise


def verify_ipa():
    subprocess.run([sys.executable, "native/scripts/prepare-store-export.py", "verify-ipa", str(TARGET.parent)], check=True)


def apple_preflight():
    # The CLI retrieves the current TestFlight build number for this exact Apple app.
    # Apple App ID is supplied by secure configuration, not guessed.
    result = subprocess.run([
        "app-store-connect", "get-latest-build-number",
        os.environ["APP_STORE_APPLE_ID"], "--version-string=0.1.0", "--platform=IOS",
    ], capture_output=True, text=True, check=True)
    value = result.stdout.strip()
    if not value.isdigit():
        raise ValueError("Could not establish Apple's latest build number; upload blocked.")
    if int(value) >= 16:
        raise ValueError("Apple already has build 16 or higher; upload blocked.")
    # This checks latest visible TestFlight build; pending uploads/reservations might not be visible.
    # A separate authoritative processing/upload inventory check is required before upload.
    if os.environ.get("REACH_APPLE_UPLOADS_CLEAR") != "CONFIRMED_NO_BUILD_16_OR_HIGHER":
        raise ValueError("Apple processing/upload inventory not confirmed; upload blocked.")
    print("Latest visible Apple TestFlight build:", value, "; separate upload inventory confirmation supplied.")


def upload():
    preflight()
    if not TARGET.is_file():
        raise ValueError("Original IPA not present.")
    if hashlib.sha256(TARGET.read_bytes()).hexdigest() != os.environ["REACH_ORIGINAL_IPA_SHA256"].lower():
        raise ValueError("IPA hash changed before upload.")
    apple_preflight()
    env = {k: v for k, v in os.environ.items() if not k.startswith("APP_STORE_CONNECT_") or k in (
        "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER", "APP_STORE_CONNECT_PRIVATE_KEY")}
    env.pop("APP_SPECIFIC_PASSWORD", None)
    env.pop("APPLE_ID", None)
    subprocess.run(["app-store-connect", "publish", "--path", str(TARGET),
                    "--enable-package-validation"], env=env, check=True)
    Path("build-logs").mkdir(exist_ok=True)
    Path("build-logs/build16-upload-result.json").write_text(json.dumps({
        "bundleID": "com.reachprototype.app", "version": "0.1.0", "build": "16",
        "sha256": os.environ["REACH_ORIGINAL_IPA_SHA256"].lower(),
        "uploadCommandSucceeded": True, "appleProcessing": "not_yet_verified",
        "testersDistributed": False}, indent=2) + "\n")
    print("Upload command succeeded; Apple processing must be verified separately. No tester distribution.")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("retrieve", "verify", "upload"):
            raise ValueError("Usage: upload_existing_build16.py retrieve|verify|upload")
        {"retrieve": retrieve, "verify": verify_ipa, "upload": upload}[sys.argv[1]]()
    except Exception as error:
        print("RELEASE HOLD:", str(error), file=sys.stderr)
        sys.exit(1)
