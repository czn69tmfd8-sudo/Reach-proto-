#!/usr/bin/env python3
"""Fail export if an archive uses simulator identity or a non-staging client config."""
from pathlib import Path
import plistlib
import subprocess
import sys

def verify(app):
    app=Path(app)
    with (app/'Info.plist').open('rb') as f: info=plistlib.load(f)
    with (app/'GoogleService-Info.plist').open('rb') as f: firebase=plistlib.load(f)
    if info.get('CFBundleIdentifier')!='com.reachprototype.app' or firebase.get('BUNDLE_ID')!='com.reachprototype.app' or firebase.get('PROJECT_ID')!='reach-staging-a4745':
        raise ValueError('Archive must use the REACH bundle and staging Firebase project.')
    if info.get('DTPlatformName')!='iphoneos' or not (app/'embedded.mobileprovision').is_file():
        raise ValueError('Archive must be a provisioned physical iPhone application.')
    entitlements=subprocess.run(['codesign','-d','--entitlements',':-',str(app)],capture_output=True,check=True).stdout
    identity=plistlib.loads(entitlements).get('application-identifier','')
    if identity.startswith('REACHSIM00.') or not identity.endswith('.com.reachprototype.app'):
        raise ValueError('Archive does not have an Apple device application identifier.')
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True,capture_output=True)

if __name__=='__main__':
    try:
        verify(sys.argv[1]); print('Device archive staging configuration and code signature verified.')
    except Exception:
        print('Device archive verification failed; no IPA should be distributed.')
        raise SystemExit(1)
