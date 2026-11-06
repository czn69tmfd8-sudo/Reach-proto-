#!/usr/bin/env python3
"""Run portable policy/store tests with Swift 6, without claiming an iOS SDK build.

Requires Swift with Foundation and XCTest (Linux or macOS). Firebase, UIKit,
Keychain and real WebRTC SDK tests must still run in the Xcode simulator suite.
"""
import os
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

native = Path(__file__).resolve().parents[1]
sources = [
    *sorted((native/'REACH/Models').glob('*.swift')),
    *[native/'REACH/Firebase'/name for name in [
        'FirebaseContract.swift', 'FirebaseProtocols.swift', 'ReachEnvironment.swift',
        'NativePairingPolicy.swift', 'PairSessionInterpreter.swift', 'ReachRoomCoordinator.swift']],
    *[native/'REACH/Media'/name for name in [
        'CallbackDeadline.swift', 'ReachReconnectPolicy.swift', 'ReachSignalingValidation.swift',
        'SignalingInbox.swift', 'WebRTCSignalingContract.swift', 'ReachTransportWatchdog.swift', 'CameraCaptureLifetime.swift', 'LocalCandidateOutbox.swift']],
    *[native/'REACH/Services'/name for name in ['ReachServices.swift', 'MockReachServices.swift', 'SessionCleanupDeadline.swift']],
]
test_names = [
    'ReachSignalingValidationTests', 'ReachRoomCoordinatorTests', 'PairSessionInterpreterTests',
    'ReachConnectionMachineTests', 'ReachJoinPolicyTests', 'CallbackDeadlineTests',
    'ReachMediaPolicyTests', 'SignalingInboxTests', 'ReachEnvironmentTests',
    'ReachSessionLifecycleTests', 'ReachReconnectPolicyTests', 'SessionContinuityPolicyTests',
    'ReachTransportStateTests', 'MockReachBackendTests', 'PairingAuthorizationTests',
    'NativePairingPolicyTests', 'IdentityMigrationPolicyTests', 'ReachTransportWatchdogTests', 'CameraCaptureLifetimeTests', 'SessionCleanupDeadlineTests', 'LocalCandidateOutboxTests',
]
tests = [native/'REACHTests'/f'{name}.swift' for name in test_names]
swift = os.environ.get('SWIFTC') or shutil.which('swiftc')
if not swift:
    raise SystemExit('swiftc is required; this script does not install a toolchain.')
with tempfile.TemporaryDirectory(prefix='reach-portable-') as temporary:
    out = Path(temporary)
    # The application policies compile under strict Swift 6 concurrency checking.
    subprocess.run([swift, '-swift-version', '6', '-enable-testing', '-emit-module',
        '-emit-library', '-module-name', 'REACH', *map(str, sources),
        '-o', str(out/('libREACH.dylib' if sys.platform == 'darwin' else 'libREACH.so'))], cwd=out, check=True)
    entries = []
    for path in tests:
        methods = re.findall(r'func (test\w+)\([^)]*\)(\s+async)?', path.read_text())
        if not methods:
            raise SystemExit(f'No discoverable tests in {path.name}')
        entries.append('testCase([' + ','.join(
            f'("{method}", ' + (f'asyncTest({path.stem}.{method})' if async_ else f'{path.stem}.{method}') + ')'
            for method, async_ in methods) + '])')
    main = out/'main.swift'
    main.write_text('import XCTest\nXCTMain([' + ','.join(entries) + '])\n')
    # Linux XCTest's legacy discovery wrappers require Swift 5 compatibility mode;
    # the application library above is still built in Swift 6 mode.
    subprocess.run([swift, '-swift-version', '5', '-I', str(out), '-L', str(out),
        '-lREACH', *map(str, tests), str(main), '-o', str(out/'run-tests')], check=True)
    environment = dict(os.environ)
    for variable in ['LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH']:
        environment[variable] = str(out) + os.pathsep + environment.get(variable, '')
    try:
        subprocess.run([str(out/'run-tests')], env=environment, check=True)
    except subprocess.CalledProcessError as failure:
        # Preserve a reproducible harness instead of deleting it on a runtime
        # crash. No retry and no conversion of a failed run into success.
        diagnostic = native/'build-logs/portable-failure'
        diagnostic.mkdir(parents=True, exist_ok=True)
        for artifact in out.iterdir():
            if artifact.is_file():
                shutil.copy2(artifact, diagnostic/artifact.name)
        (diagnostic/'failure.json').write_text(json.dumps({
            'platform': sys.platform, 'returnCode': failure.returncode,
            'swiftVersion': subprocess.check_output([swift, '--version'], text=True).strip(),
            'note': 'Original process failure retained. No automatic retry performed.'
        }, indent=2) + '\n')
        print(f'Portable harness diagnostics saved in {diagnostic}', file=sys.stderr)
        raise
