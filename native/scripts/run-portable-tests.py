#!/usr/bin/env python3
"""Run portable policy/store tests with Swift 6, without claiming an iOS SDK build.

On macOS, SwiftPM resolves Apple XCTest and discovers tests automatically.
On Linux, the existing corelibs XCTest harness is retained. Firebase, UIKit,
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
        'SignalingInbox.swift', 'WebRTCSignalingContract.swift', 'ReachTransportWatchdog.swift', 'CameraCaptureLifetime.swift', 'LocalCandidateOutbox.swift', 'ReachMediaControls.swift']],
    *[native/'REACH/Services'/name for name in ['ReachServices.swift', 'MockReachServices.swift', 'SessionCleanupDeadline.swift', 'LocalRelationshipFile.swift']],
]
test_names = [
    'ReachSignalingValidationTests', 'ReachRoomCoordinatorTests', 'PairSessionInterpreterTests',
    'RelationshipJournalTests', 'LocalRelationshipFileTests', 'SharedContentPolicyTests', 'ReachCallReviewTests',
    'ReachHomeAvailabilityTests', 'ReachAppearancePreferencesTests',
    'ReachConnectionMachineTests', 'ReachJoinPolicyTests', 'CallbackDeadlineTests',
    'ReachMediaPolicyTests', 'SignalingInboxTests', 'ReachEnvironmentTests',
    'ReachSessionLifecycleTests', 'ReachReconnectPolicyTests', 'SessionContinuityPolicyTests',
    'ReachTransportStateTests', 'MockReachBackendTests', 'PairingAuthorizationTests',
    'NativePairingPolicyTests', 'IdentityMigrationPolicyTests', 'ReachTransportWatchdogTests', 'CameraCaptureLifetimeTests', 'SessionCleanupDeadlineTests', 'LocalCandidateOutboxTests', 'ReachMediaControlsTests',
]
tests = [native/'REACHTests'/f'{name}.swift' for name in test_names]


def write_macos_package(directory, source_paths=sources, test_paths=tests):
    """Let SwiftPM locate Apple's developer XCTest framework and discover tests."""
    directory = Path(directory)
    for folder, paths in [('Sources/REACH', source_paths), ('Tests/REACHTests', test_paths)]:
        destination = directory / folder
        destination.mkdir(parents=True, exist_ok=True)
        names = [path.name for path in paths]
        if len(names) != len(set(names)):
            raise ValueError('Portable package source filenames must be unique.')
        for path in paths:
            shutil.copy2(path, destination / path.name)
    (directory / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "REACHPortableValidation",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "REACH", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "REACHTests", dependencies: ["REACH"],
                    swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
''')


def run_macos_tests(directory, swiftc):
    write_macos_package(directory)
    swift_driver = Path(swiftc).resolve().with_name('swift')
    if not swift_driver.is_file():
        raise SystemExit('The selected Swift toolchain must include the swift package driver.')
    # No external dependencies or manual XCTest framework/search/linker paths.
    # SwiftPM uses Xcode's SDK and performs native macOS XCTest discovery.
    command = [str(swift_driver), 'test', '--package-path', str(directory), '--enable-xctest']
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError:
        diagnostic = native / 'build-logs/portable-macos-failure'
        diagnostic.mkdir(parents=True, exist_ok=True)
        shutil.copy2(Path(directory) / 'Package.swift', diagnostic / 'Package.swift')
        for folder in ['Sources', 'Tests']:
            shutil.copytree(Path(directory) / folder, diagnostic / folder, dirs_exist_ok=True)
        raise


def main():
    swift = os.environ.get('SWIFTC') or shutil.which('swiftc')
    if not swift:
        raise SystemExit('swiftc is required; this script does not install a toolchain.')
    with tempfile.TemporaryDirectory(prefix='reach-portable-') as temporary:
        out = Path(temporary)
        if sys.platform == 'darwin':
            run_macos_tests(out, swift)
            return
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
        if sys.platform == 'linux' and os.environ.get('REACH_PORTABLE_LOADER_TRACE') == '1':
            # Loader mappings permit offline symbolication without ptrace access.
            environment['LD_DEBUG'] = 'files'
            environment['LD_DEBUG_OUTPUT'] = str(out/'loader-trace')
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


if __name__ == '__main__':
    main()
