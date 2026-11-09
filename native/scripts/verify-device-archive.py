#!/usr/bin/env python3
"""Fail export if an archive uses simulator identity or a non-staging client config."""
from pathlib import Path
from datetime import datetime, timezone
import plistlib
import subprocess
import sys
import argparse

def verify(app, distribution="ad_hoc", expected_team=None):
    app=Path(app)
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
    args=parser.parse_args()
    try:
        if args.distribution == 'app_store' and not args.expected_team:
            raise ValueError('TestFlight verification requires the expected Apple Team ID.')
        verify(args.app, args.distribution, args.expected_team)
        print('Device archive staging configuration and distribution signature verified.')
    except Exception:
        print('Device archive verification failed; no IPA should be distributed.')
        raise SystemExit(1)
