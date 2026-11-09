#!/usr/bin/env python3
"""Validate manual TestFlight archive/export inputs. Never contacts Apple or uploads."""
import argparse
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import tempfile
import zipfile


def inputs(environment):
    team=environment.get('REACH_APPLE_TEAM_ID','')
    number=environment.get('REACH_IOS_BUILD_NUMBER','')
    if not re.fullmatch(r'[A-Z0-9]{10}',team):
        raise ValueError('Set REACH_APPLE_TEAM_ID to the actual 10-character Apple Team ID.')
    if not re.fullmatch(r'[1-9][0-9]{0,3}',number):
        raise ValueError('Set REACH_IOS_BUILD_NUMBER to an unused integer from 1 through 9999.')
    return team,number


def validate_test_results(summary, expected=None):
    # Build 3 had 164 tests. The approved home-screen commit adds four more.
    passed = summary.get('passedTests')
    if (
        summary.get('result') != 'Passed'
        or type(passed) is not int
        or passed < 168
        or (expected is not None and passed != expected)
        or summary.get('totalTestCount') != passed
        or summary.get('failedTests') != 0
        or summary.get('skippedTests') != 0
        or summary.get('expectedFailures') != 0
    ):
        count = 'at least 168' if expected is None else f'exactly {expected}'
        raise ValueError(f'Archive requires {count} passing native tests and no failures or skips.')


def validate_export(options,team):
    if options.get('method') not in ('app-store','app-store-connect'):
        raise ValueError('TestFlight export requires an App Store distribution method.')
    if options.get('teamID') != team:
        raise ValueError('Export options must match the explicitly selected Apple Team ID.')
    profiles=options.get('provisioningProfiles',{})
    if set(profiles) != {'com.reachprototype.app'} or not isinstance(profiles['com.reachprototype.app'],str) or not profiles['com.reachprototype.app']:
        raise ValueError('Export must provision only the exact REACH bundle.')
    if options.get('destination','export') != 'export':
        raise ValueError('Only local export is authorized; upload destination is forbidden.')
    if options.get('uploadSymbols',False) is not False:
        raise ValueError('Export must not upload symbols or other artifacts.')
    if options.get('testFlightInternalTestingOnly') is not True:
        raise ValueError('Export must be restricted to TestFlight internal testing.')
    if options.get('manageAppVersionAndBuildNumber') is not False:
        raise ValueError('Export must preserve the approved version and build number.')


def verify_ipa(directory,team,number):
    files=list(Path(directory).glob('*.ipa'))
    if len(files)!=1:raise ValueError('Expected exactly one exported IPA.')
    spec=importlib.util.spec_from_file_location('archive',Path(__file__).with_name('verify-device-archive.py'))
    archive=importlib.util.module_from_spec(spec);spec.loader.exec_module(archive)
    with tempfile.TemporaryDirectory() as folder:
        with zipfile.ZipFile(files[0]) as package:
            for entry in package.namelist():
                path=PurePosixPath(entry)
                if path.is_absolute() or '..' in path.parts:raise ValueError('Unsafe IPA archive path.')
            package.extractall(folder)
            for entry in package.infolist():
                target=Path(folder)/entry.filename
                mode=(entry.external_attr >> 16) & 0o777
                if mode:target.chmod(mode)
        apps=list((Path(folder)/'Payload').glob('*.app'))
        if len(apps)!=1:raise ValueError('Expected exactly one app in the IPA.')
        app=apps[0]
        archive.verify(app,distribution='app_store',expected_team=team)
        info=plistlib.loads((app/'Info.plist').read_bytes())
        validate_release_resources(app,info,number)
        if not all(info.get(k) for k in ('NSCameraUsageDescription','NSMicrophoneUsageDescription')):
            raise ValueError('Camera and microphone purpose strings are required.')
        if not (app/'PrivacyInfo.xcprivacy').is_file() or not info.get('CFBundleIcons'):
            raise ValueError('App icon and required-reason privacy manifest must be bundled.')



def validate_release_resources(app,info,number):
    if str(info.get('CFBundleVersion')) != number:
        raise ValueError('Exported build number differs from selected input.')
    if info.get('CFBundleShortVersionString') != '0.1.0':
        raise ValueError('This preparation requires REACH version 0.1.0.')
    assets=Path(app)/'Assets.car'
    if not assets.is_file() or assets.stat().st_size == 0:
        raise ValueError('Compiled image assets must be present in the exported app.')


def promote_ipa(source,destination,team,number):
    # Only this destination is collected by the App Store Connect publisher.
    # Verification failure must leave no publishable artifact, even if a failed
    # workflow proceeds to artifact collection/publishing.
    destination=Path(destination)
    if destination.exists():raise ValueError('Publishable IPA directory must not already exist.')
    verify_ipa(source,team,number)
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as folder:
        ipa=next(Path(source).glob('*.ipa'))
        shutil.copy2(ipa,Path(folder)/ipa.name)
        Path(folder).rename(destination)
        # TemporaryDirectory cleanup tolerates the renamed staging directory.


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['inputs','test-results','export','verify-ipa','promote-ipa'])
    parser.add_argument('path',nargs='?')
    parser.add_argument('destination',nargs='?')
    parser.add_argument('--expected-tests', type=int)
    args=parser.parse_args()
    try:
        team,number=inputs(os.environ)
        if args.action=='test-results':
            validate_test_results(json.loads(Path(args.path).read_text()), args.expected_tests)
        elif args.action=='export':
            path=Path(args.path);options=plistlib.loads(path.read_bytes())
            # Keep export local; only the separate publisher may upload a verified IPA.
            options['destination'] = 'export'
            options['uploadSymbols'] = False
            options['testFlightInternalTestingOnly'] = True
            options['manageAppVersionAndBuildNumber'] = False
            validate_export(options,team)
            path.write_bytes(plistlib.dumps(options))
        elif args.action=='verify-ipa':verify_ipa(args.path,team,number)
        elif args.action=='promote-ipa':promote_ipa(args.path,args.destination,team,number)
        print('TestFlight preparation checks passed; this script performs no upload.')
    except Exception as error:
        print(str(error));raise SystemExit(1)
