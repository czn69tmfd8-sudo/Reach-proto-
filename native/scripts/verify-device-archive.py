#!/usr/bin/env python3
"""Fail export if an archive uses simulator identity or a non-staging client config."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import plistlib
import tempfile
import subprocess
import sys
import argparse

def verify(app, distribution="ad_hoc", expected_team=None, signing_report=None):
    app=Path(app).resolve()
    with (app/'Info.plist').open('rb') as f: info=plistlib.load(f)
    with (app/'GoogleService-Info.plist').open('rb') as f: firebase=plistlib.load(f)
    if info.get('CFBundleIdentifier')!='com.reachprototype.app' or firebase.get('BUNDLE_ID')!='com.reachprototype.app' or firebase.get('PROJECT_ID')!='reach-staging-a4745':
        raise ValueError('Archive must use the REACH bundle and staging Firebase project.')
    if info.get('DTPlatformName')!='iphoneos' or not (app/'embedded.mobileprovision').is_file():
        raise ValueError('Archive must be a provisioned physical iPhone application.')
    entitlements=subprocess.run(['codesign','-d','--entitlements',':-',str(app)],capture_output=True,check=True).stdout
    entitlements=plistlib.loads(entitlements)
    identity=entitlements.get('application-identifier','')
    if identity.startswith('REACHSIM00.') or not identity.endswith('.com.reachprototype.app'):
        raise ValueError('Archive does not have an Apple device application identifier.')
    profile=plistlib.loads(subprocess.run(
        ['security','cms','-D','-i',str(app/'embedded.mobileprovision')],
        capture_output=True,check=True).stdout)
    validate_profile(profile, entitlements, distribution=distribution, expected_team=expected_team)
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True,capture_output=True)

    if signing_report:
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(['codesign', '-d', '--extract-certificates', str(app)],
                           cwd=directory, check=True, capture_output=True)
            leaf = Path(directory) / 'codesign0'
            certificate = leaf.read_bytes()
            subprocess.run(['openssl', 'x509', '-inform', 'DER', '-in', str(leaf),
                            '-noout', '-checkend', '0'], check=True, capture_output=True)
        report = signing_metadata(info, profile, entitlements, certificate)
        Path(signing_report).write_text(json.dumps(report, indent=2) + '\n')


def signing_metadata(info, profile, entitlements, certificate):
    if not certificate or certificate not in profile.get('DeveloperCertificates', []):
        raise ValueError('The actual signing certificate is not authorized by the provisioning profile.')

    identity = entitlements['application-identifier']
    prefix = identity.split('.', 1)[0]
    if prefix not in profile.get('ApplicationIdentifierPrefix', []):
        raise ValueError('The provisioning profile does not authorize the signed application prefix.')
    groups = entitlements.get('keychain-access-groups', [])
    allowed = profile['Entitlements'].get('keychain-access-groups', [])
    if not isinstance(groups, list) or any(
        not isinstance(group, str) or not any(
            pattern == group or (pattern.endswith('.*') and group.startswith(pattern[:-1]))
            for pattern in allowed
        ) for group in groups
    ):
        raise ValueError('The provisioning profile does not authorize the signed Keychain groups.')
    return {
        'bundleID': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'],
        'build': info['CFBundleVersion'],
        'teamID': entitlements['com.apple.developer.team-identifier'],
        'applicationIdentifier': identity,
        'keychainAccessGroups': groups,
        'applicationGroups': entitlements.get('com.apple.security.application-groups', []),
        'signingCertificateSHA256': hashlib.sha256(certificate).hexdigest(),
        'profileExpirationUTC': profile['ExpirationDate'].replace(tzinfo=timezone.utc).isoformat(),
        'firebaseProject': 'reach-staging-a4745',
    }


def validate_profile(profile, entitlements, now=None, distribution="ad_hoc", expected_team=None):
    """Accept only the requested distribution mode for this exact staging app."""
    if distribution not in ("ad_hoc", "app_store"):
        raise ValueError("Unsupported signing distribution mode.")
    now=now or datetime.now(timezone.utc)
    expiry=profile.get('ExpirationDate')
    if not isinstance(expiry,datetime) or expiry.replace(tzinfo=timezone.utc)<=now:
        raise ValueError('Device provisioning profile is missing or expired.')
    permissions=profile.get('Entitlements',{})
    teams=profile.get('TeamIdentifier',[])
    team=entitlements.get('com.apple.developer.team-identifier')
    if (expected_team is not None and team != expected_team) or not team or teams!=[team] or permissions.get('com.apple.developer.team-identifier')!=team:
        raise ValueError('Profile and application signing teams must match.')
    identity=entitlements.get('application-identifier')
    if not isinstance(identity,str) or permissions.get('application-identifier')!=identity or not identity.endswith('.com.reachprototype.app'):
        raise ValueError('Profile must authorize the exact REACH application identity.')
    devices=profile.get('ProvisionedDevices')
    if distribution == 'ad_hoc':
        if not isinstance(devices,list) or not devices or any(not isinstance(d,str) or not d.strip() for d in devices):
            raise ValueError('Ad-hoc profile must include registered test devices.')
    elif 'ProvisionedDevices' in profile or permissions.get('beta-reports-active') is not True:
        raise ValueError('TestFlight requires an App Store distribution profile, not ad-hoc or development signing.')
    if profile.get('ProvisionsAllDevices',False) is not False or permissions.get('get-task-allow') is not False or entitlements.get('get-task-allow') is not False:
        raise ValueError('Distribution signing must not allow debugging or enterprise distribution.')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('app')
    parser.add_argument('--distribution',choices=['ad_hoc','app_store'],default='ad_hoc')
    parser.add_argument('--expected-team')
    parser.add_argument('--signing-report', type=Path)
    args=parser.parse_args()
    try:
        if args.distribution == 'app_store' and not args.expected_team:
            raise ValueError('TestFlight verification requires the expected Apple Team ID.')
        verify(args.app, args.distribution, args.expected_team, args.signing_report)
        print('Device archive staging configuration and distribution signature verified.')
    except Exception:
        print('Device archive verification failed; no IPA should be distributed.')
        raise SystemExit(1)
