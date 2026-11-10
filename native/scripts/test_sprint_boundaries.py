"""Offline regression checks for staging, release baseline and private-content isolation."""
from pathlib import Path
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASELINE = 'e7591c7c3ebd4c73c35a606de019859df60f9f48'

class SprintBoundaryTests(unittest.TestCase):
    def test_existing_security_and_media_policies_remain_byte_identical(self):
        protected = [
            'native/firebase/firestore.rules',
            'native/firebase/reviews/staging-2026-11-06-hardened/merged.rules',
            'native/REACH/Firebase/ReachEnvironment.swift',
            'native/REACH/Models/PairingAuthorization.swift',
            'native/REACH/Models/ReachHomeAvailability.swift',
            'native/REACH/Media/NativeWebRTCPeer.swift',
            'native/REACH/Media/ReachTransportWatchdog.swift',
            'native/REACH/Services/PermissionService.swift',
            'native/project.yml',
        ]
        for path in protected:
            with self.subTest(path=path):
                original = subprocess.check_output(['git', 'show', BASELINE + ':' + path], cwd=ROOT)
                current = (ROOT / path).read_bytes()
                if path == 'native/project.yml':
                    # One reviewed additive dependency is necessary for private
                    # Storage photo transport. All pre-existing project bytes,
                    # signing settings, target definitions and media deps must
                    # still match the historical baseline exactly.
                    addition = b'      - package: Firebase\n        product: FirebaseStorage\n'
                    self.assertEqual(current.count(addition), 1)
                    self.assertEqual(current.replace(addition, b''), original)
                else:
                    self.assertEqual(current, original)

    def test_private_content_has_no_backend_import_or_upload_dependency(self):
        for path in ['native/REACH/Models/RelationshipJournal.swift',
                     'native/REACH/Services/LocalRelationshipFile.swift',
                     'native/REACH/Services/RelationshipJournalStore.swift']:
            source = (ROOT / path).read_text()
            for forbidden in ['import Firebase', 'URLSession', 'Firestore', 'ReachCollections', 'SharedContentDraft']:
                with self.subTest(path=path, forbidden=forbidden):
                    self.assertNotIn(forbidden, source)

    def test_proposed_rules_are_not_a_deployment_target(self):
        configs = list(ROOT.glob('**/firebase.json'))
        configs = [p for p in configs if 'node_modules' not in p.parts]
        self.assertTrue(configs)
        for path in configs:
            self.assertNotIn('firestore.proposed.rules', path.read_text())
        self.assertNotIn('firestore.proposed.rules', (ROOT / 'codemagic.yaml').read_text())

    def test_build_five_legacy_paths_and_release_workflow_are_untouched(self):
        baseline = '641cc0debc41f3e60517ab1880d8444ab9c5dc94'
        protected = [
            'firebase.json', '.firebaserc', 'index.html', 'staging',
            'native/firebase/firestore.rules', 'native/firebase/firebase.json',
            'native/REACH/Firebase/FirebaseBootstrap.swift',
            'native/REACH/Firebase/FirebaseDependencyFactory.swift',
            'native/REACH/Firebase/FirebaseAuthProvider.swift',
            'native/REACH/Services/LocalRelationshipFile.swift',
            'native/REACH/Services/RelationshipJournalStore.swift',
            'native/REACH/Models/RelationshipJournal.swift',
        ]
        diff = subprocess.check_output(['git', 'diff', '--name-only', baseline, '--', *protected], cwd=ROOT)
        self.assertEqual(diff, b'')
        candidate = 'relationship-space.proposed.rules'
        for path in [ROOT/'firebase.json', ROOT/'native/firebase/firebase.json', ROOT/'codemagic.yaml']:
            self.assertNotIn(candidate, path.read_text())

    def test_visual_changes_are_limited_to_ui_and_local_daily_messages(self):
        source = (ROOT / 'native/REACH/Views/ReachDailyMomentView.swift').read_text()
        for forbidden in ['import Firebase', 'Firestore', 'URLSession', 'NativeWebRTCPeer', 'PairingAuthorization']:
            self.assertNotIn(forbidden, source)
        self.assertIn('ReachDailyMomentView(now: timeline.date)',
                      (ROOT / 'native/REACH/Views/RootView.swift').read_text())

    def test_relationship_validation_signs_only_the_simulator_and_preserves_build_five_workflows(self):
        baseline = '641cc0debc41f3e60517ab1880d8444ab9c5dc94'
        original = subprocess.check_output(['git', 'show', f'{baseline}:codemagic.yaml'], cwd=ROOT).decode()
        current = (ROOT / 'codemagic.yaml').read_text()
        marker = '  reach-ios-simulator:'
        prefix, tail = current.split(marker, 1)
        self.assertEqual('workflows:\n' + marker + tail, original)
        prefix = prefix.split('  reach-ios-build6-archive-only:', 1)[0]
        self.assertTrue(prefix.startswith('workflows:\n  reach-ios-relationship-validation:'))
        for forbidden in ['publishing:', 'triggering:', 'artifacts:', 'groups:', 'ios_signing:',
                          'integrations:', 'archive', 'upload-symbols', 'firebase deploy', 'use-profiles',
                          'skip-testing', 'continue-on-error']:
            self.assertNotIn(forbidden, prefix)
        _, simulator = prefix.split('      - name: Run simulator XCTest', 1)
        simulator, device = simulator.split('      - name: Compile unsigned physical iPhone target', 1)
        self.assertIn('-destination "platform=iOS Simulator,id=$DEVICE_ID"', simulator)
        self.assertIn('CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="-" test || TEST_EXIT=$?', simulator)
        self.assertIn('exit "$TEST_EXIT"', simulator)
        self.assertNotIn('CODE_SIGNING_ALLOWED=NO', simulator)
        self.assertIn("-destination 'generic/platform=iOS'", device)
        self.assertIn('CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build', device)
        self.assertEqual(prefix.count('CODE_SIGNING_ALLOWED=YES'), 1)
        self.assertEqual(prefix.count('CODE_SIGNING_ALLOWED=NO'), 1)
        project = (ROOT / 'native/project.yml').read_text()
        self.assertIn('"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]": Configuration/Simulator.entitlements', project)
        entitlements = plistlib.loads((ROOT / 'native/Configuration/Simulator.entitlements').read_bytes())
        app_id = 'REACHSIM00.com.reachprototype.app'
        self.assertEqual(entitlements['application-identifier'], app_id)
        self.assertEqual(entitlements['keychain-access-groups'], [app_id])
        self.assertIn('verify-sprint-source.py', prefix)
        self.assertIn('GoogleService-Info.plist', prefix)
        self.assertIn('xcresulttool get test-results summary', prefix)

    def test_new_validation_workflow_has_no_publisher_credentials_or_trigger(self):
        workflow = (ROOT / 'codemagic.yaml').read_text().split('  reach-ios-sprint-validation:',1)[1].split('  reach-ios-testflight-archive:',1)[0]
        for forbidden in ['publishing:', 'triggering:', 'groups:', 'ios_signing:', 'integrations:', 'emulators:exec', 'npm test', 'build-ipa', '-exportArchive']:
            self.assertNotIn(forbidden, workflow)
        self.assertIn('CODE_SIGNING_ALLOWED=NO build', workflow)
        self.assertIn('bash scripts/run-simulator-tests.sh', workflow)
