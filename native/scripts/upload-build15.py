#!/usr/bin/env python3
"""Gated binary upload through the existing Codemagic Apple integration.

Never submits for external beta review, public release, or tester assignment.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

CREDENTIALS = {
    'APP_STORE_CONNECT_ISSUER_ID',
    'APP_STORE_CONNECT_KEY_IDENTIFIER',
    'APP_STORE_CONNECT_PRIVATE_KEY',
}


def preflight(env):
    required = {
        'CM_BRANCH': 'feature/adventure-book-single-app-integration',
        'REACH_SIGNED_ARCHIVE_APPROVAL': 'UPLOAD_INTERNAL_BUILD_15',
        'REACH_APPLE_TEAM_ID': 'GFUK853ZT5',
        'REACH_IOS_BUILD_NUMBER': '15',
    }
    if any(env.get(k) != v for k, v in required.items()) or env.get('CM_PULL_REQUEST_DEST'):
        raise ValueError('Build 15 upload authorization or release identity is invalid.')
    if any(not env.get(k, '').strip() for k in CREDENTIALS):
        raise ValueError('Existing REACH Codemagic App Store Connect integration credentials are unavailable.')


def upload(directory, env):
    preflight(env)
    files = list(Path(directory).glob('*.ipa'))
    if len(files) != 1:
        raise ValueError('Exactly one verified Build 15 IPA is required.')
    # Reject ambient CLI submission/release options inherited from variable groups.
    clean = {k: v for k, v in env.items()
             if not k.startswith('APP_STORE_CONNECT_') or k in CREDENTIALS}
    clean.pop('APP_SPECIFIC_PASSWORD', None)
    clean.pop('APPLE_ID', None)
    subprocess.run([
        'app-store-connect', 'publish', '--path', str(files[0]),
        '--enable-package-validation',
    ], env=clean, check=True)
    return {'bundleID': 'com.reachprototype.app', 'version': '0.1.0', 'build': '15',
            'uploadCommandSucceeded': True, 'processingStatus': 'not_yet_verified',
            'testerAssignment': 'pending_App_Store_Connect_verification'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['preflight', 'upload'])
    args = parser.parse_args()
    try:
        if args.action == 'preflight':
            preflight(os.environ)
            print('Existing integration available; no credential values displayed.')
        else:
            result = upload('build/build15-verified', os.environ)
            Path('build-logs/build15-upload-result.json').write_text(json.dumps(result, indent=2) + '\n')
            print('Upload command succeeded. Apple processing, compliance and internal availability require verification.')
    except (ValueError, subprocess.CalledProcessError) as error:
        print(str(error) if isinstance(error, ValueError) else 'Apple upload failed. No success status recorded.')
        raise SystemExit(1)
