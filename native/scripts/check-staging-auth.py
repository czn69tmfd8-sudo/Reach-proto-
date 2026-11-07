#!/usr/bin/env python3
"""Opt-in live staging Auth smoke test. No Firestore writes, credentials in logs, or deployments."""
import argparse
import json
import plistlib
import re
import urllib.error
import urllib.parse
import urllib.request

PROJECT = 'reach-staging-a4745'
BUNDLE = 'com.reachprototype.app'
# Public project number from the approved staging iOS app configuration.
PROJECT_NUMBER = '537916955208'
BASE = 'https://identitytoolkit.googleapis.com/v1/'

class CheckError(Exception):
    pass

def request_json(method, url, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=body, method=method, headers={
        'Content-Type': 'application/json', 'X-Ios-Bundle-Identifier': BUNDLE
    })
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        try:
            message = json.load(error).get('error', {}).get('message', '')
            code = re.match(r'[A-Z][A-Z0-9_]+', message)
        except (ValueError, AttributeError):
            code = None
        raise CheckError(code.group(0) if code else f'HTTP_{error.code}') from None
    except (urllib.error.URLError, TimeoutError):
        raise CheckError('NETWORK_UNAVAILABLE') from None

def check_auth(config, transport=request_json):
    if config.get('PROJECT_ID') != PROJECT or config.get('BUNDLE_ID') != BUNDLE:
        raise CheckError('STAGING_CONFIGURATION_MISMATCH')
    key = config.get('API_KEY')
    if not isinstance(key, str) or not key:
        raise CheckError('MISSING_API_KEY')
    query = '?' + urllib.parse.urlencode({'key': key})
    # This read-only call verifies the KEY's actual project before creating a user.
    # A plist's PROJECT_ID label alone cannot establish which project owns a key.
    public_config = transport('GET', BASE + 'projects' + query)
    actual = public_config.get('projectId')
    numeric_match = (actual == PROJECT_NUMBER and config.get('GCM_SENDER_ID') == PROJECT_NUMBER
                     and config.get('GOOGLE_APP_ID', '').startswith(f'1:{PROJECT_NUMBER}:ios:')
                     and f'{PROJECT}.firebaseapp.com' in public_config.get('authorizedDomains', []))
    if actual != PROJECT and not numeric_match:
        raise CheckError('API_KEY_PROJECT_NOT_VERIFIED_NO_USER_CREATED')
    token = None
    try:
        signed = transport('POST', BASE + 'accounts:signUp' + query, {'returnSecureToken': True})
        token = signed.get('idToken')
        uid = signed.get('localId')
        if not token or not uid:
            raise CheckError('INCOMPLETE_SIGN_IN_RESPONSE')
        users = transport('POST', BASE + 'accounts:lookup' + query, {'idToken': token}).get('users', [])
        if len(users) != 1 or users[0].get('localId') != uid or users[0].get('email') or users[0].get('providerUserInfo'):
            raise CheckError('ANONYMOUS_IDENTITY_NOT_VERIFIED')
    finally:
        if token:
            try:
                # Only the brand-new account created above is deleted. No existing
                # app account is loaded, signed out, reset, or otherwise modified.
                transport('POST', BASE + 'accounts:delete' + query, {'idToken': token})
            except Exception:
                raise CheckError('TEMPORARY_STAGING_ACCOUNT_CLEANUP_NOT_CONFIRMED') from None
    return {'project': PROJECT, 'anonymousAuth': 'verified', 'temporaryAccountCleanup': 'verified',
            'nativeSDKAuth': 'not-tested', 'firestorePairing': 'not-tested'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('plist')
    parser.add_argument('--live-staging-test', action='store_true', required=True)
    args = parser.parse_args()
    try:
        with open(args.plist, 'rb') as file:
            config = plistlib.load(file)
        print(json.dumps(check_auth(config), indent=2))
    except (CheckError, OSError, ValueError) as error:
        # Never print URLs, API keys, bearer tokens, raw responses, or local UIDs.
        print(json.dumps({'project': PROJECT, 'result': 'blocked', 'reason': str(error) if isinstance(error, CheckError) else 'CONFIGURATION_UNREADABLE'}))
        raise SystemExit(1)
