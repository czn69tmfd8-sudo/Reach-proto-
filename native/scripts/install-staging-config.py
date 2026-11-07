#!/usr/bin/env python3
"""Install only REACH's staging client plist without logging its contents."""
import argparse
import base64
import os
from pathlib import Path
import plistlib

PROJECT = 'reach-staging-a4745'
BUNDLE = 'com.reachprototype.app'

def install(encoded, destination, required=False):
    if not encoded:
        if required: raise ValueError('Staging Firebase configuration is required for device builds.')
        return False
    try:
        payload = base64.b64decode(encoded, validate=True)
        config = plistlib.loads(payload)
    except Exception:
        raise ValueError('Invalid staging Firebase configuration encoding or plist.') from None
    if config.get('PROJECT_ID') != PROJECT or config.get('BUNDLE_ID') != BUNDLE:
        raise ValueError('Firebase configuration must match reach-staging-a4745 and com.reachprototype.app.')
    if not all(isinstance(config.get(key), str) and config[key] for key in ('GOOGLE_APP_ID', 'API_KEY', 'GCM_SENDER_ID')):
        raise ValueError('Staging Firebase configuration is missing required fields.')
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(destination, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, 'wb') as file:
        file.write(payload)
    destination.chmod(0o600)
    return True

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--required', action='store_true')
    parser.add_argument('--destination', default='native/REACH/GoogleService-Info.plist')
    args = parser.parse_args()
    try:
        present = install(os.environ.get('REACH_STAGING_FIREBASE_PLIST_BASE64'), args.destination, args.required)
        print('Staging Firebase configuration validated.' if present else 'No staging Firebase configuration supplied; sign-in unavailable.')
    except ValueError as error:
        print(str(error))
        raise SystemExit(1)
