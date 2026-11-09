import json
from pathlib import Path
import plistlib
import struct
import unittest

ROOT=Path(__file__).resolve().parents[1]
class AppPackagingTests(unittest.TestCase):
    def test_app_icon_is_opaque_1024_rgb_and_referenced_by_catalog(self):
        directory=ROOT/'REACH/Assets.xcassets/AppIcon.appiconset'
        entry=json.loads((directory/'Contents.json').read_text())['images'][0]
        data=(directory/entry['filename']).read_bytes()
        self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II',data[16:24]),(1024,1024))
        self.assertEqual(data[25],2) # RGB, no alpha channel.
        self.assertIn('ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon',(ROOT/'project.yml').read_text())
    def test_own_preferences_required_reason_manifest_is_packaged_with_app(self):
        p=plistlib.loads((ROOT/'REACH/PrivacyInfo.xcprivacy').read_bytes())
        self.assertFalse(p['NSPrivacyTracking'])
        self.assertEqual(p['NSPrivacyAccessedAPITypes'],[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']}])
    def test_store_upload_is_manual_and_scoped_to_testflight_workflow(self):
        other,workflow=(ROOT.parent/'codemagic.yaml').read_text().split('  reach-ios-testflight-archive:',1)
        before, after = other.split('  reach-ios-build6-testflight:', 1)
        _, after = after.split('  reach-staging-firestore-verify:', 1)
        self.assertNotIn('    publishing:', before + after)
        self.assertIn('app_store_connect: REACH Codemagic',workflow)
        self.assertIn('auth: integration',workflow)
        self.assertIn('submit_to_app_store: false',workflow)
        self.assertIn('submit_to_testflight: false',workflow)
        self.assertNotIn('beta_groups:',workflow)
        self.assertNotIn('    triggering:',workflow)
        self.assertIn('distribution_type: app_store',workflow)
        self.assertIn('bundle_identifier: com.reachprototype.app',workflow)
        self.assertIn('test "$CM_BRANCH" = "native-reach"',workflow)
        self.assertIn('test "$REACH_APPLE_TEAM_ID" = "GFUK853ZT5"',workflow)
        self.assertIn('--expected-team "$REACH_APPLE_TEAM_ID"',workflow)
    def test_unverified_exports_are_not_publisher_artifacts(self):
        workflow=(ROOT.parent/'codemagic.yaml').read_text().split('  reach-ios-testflight-archive:',1)[1]
        scripts,artifacts=workflow.split('    artifacts:',1)
        self.assertIn('-exportPath build/testflight-unverified ',scripts)
        self.assertIn('promote-ipa build/testflight-unverified build/testflight',scripts)
        self.assertIn('native/build/testflight/*.ipa',artifacts)
        self.assertNotIn('testflight-unverified',artifacts)

    def test_original_web_sunset_is_bundled_without_reencoding(self):
        import hashlib
        source=(ROOT.parent/'staging/Reach back.png').read_bytes()
        directory=ROOT/'REACH/Assets.xcassets/OriginalSunset.imageset'
        entry=json.loads((directory/'Contents.json').read_text())['images'][0]
        bundled=(directory/entry['filename']).read_bytes()
        self.assertEqual(bundled,source)
        self.assertEqual(hashlib.sha256(bundled).hexdigest(),'b1b72b03ca4f7d331daec329edf39c67136e7ae09daa180ac11b62a56a3f8efc')
        self.assertEqual(struct.unpack('>II',bundled[16:24]),(864,1536))

    def test_build_five_pins_reviewed_header_source_before_staging_config_install(self):
        workflow=(ROOT.parent/'codemagic.yaml').read_text().split('  reach-ios-testflight-archive:',1)[1]
        self.assertIn('REACH_IOS_BUILD_NUMBER: "5"',workflow)
        self.assertIn('test "$REACH_IOS_BUILD_NUMBER" = "5"',workflow)
        self.assertIn('REACH_APPROVED_APP_COMMIT: 1ef1a29efd26b06781a5f68b930eb95d4f95f119',workflow)
        self.assertIn('test "$REACH_APPROVED_APP_COMMIT" = "1ef1a29efd26b06781a5f68b930eb95d4f95f119"',workflow)
        self.assertIn('git merge-base --is-ancestor "$REACH_APPROVED_APP_COMMIT" HEAD', workflow)
        fingerprint = '656f35d64bdb5e5e36596c7eebd34afd9bdd3578e452290da10a0adfab7d038e'
        self.assertIn(f'python3 native/scripts/verify-sprint-source.py {fingerprint}', workflow)
        self.assertLess(workflow.index('verify-sprint-source.py'), workflow.index('install-staging-config.py'))
        self.assertIn('MARKETING_VERSION="0.1.0" CURRENT_PROJECT_VERSION="$REACH_IOS_BUILD_NUMBER" archive',workflow)


    def test_native_test_results_gate_runs_before_signing_archive_and_promotion(self):
        workflow = (ROOT.parent/'codemagic.yaml').read_text().split('  reach-ios-testflight-archive:', 1)[1]
        steps = [
            'rm -rf native/build/testflight native/build/testflight-unverified',
            'verify-sprint-source.py',
            'rm -f build-logs/test-summary.json',
            'bash scripts/run-simulator-tests.sh',
            'prepare-store-export.py test-results build-logs/test-summary.json',
            'xcode-project use-profiles',
            'CURRENT_PROJECT_VERSION="$REACH_IOS_BUILD_NUMBER" archive',
            'promote-ipa build/testflight-unverified build/testflight',
        ]
        positions = [workflow.index(step) for step in steps]
        self.assertEqual(positions, sorted(positions))


    def test_build_six_archive_is_manual_source_pinned_and_has_no_uploader(self):
        workflow = (ROOT.parent/'codemagic.yaml').read_text().split('  reach-ios-build6-archive-only:', 1)[1].split('  reach-ios-build6-testflight:', 1)[0]
        for forbidden in ('publishing:', 'triggering:', 'integrations:', 'app-store-connect ',
                          'firebase deploy', 'altool', 'iTMSTransporter'):
            self.assertNotIn(forbidden, workflow)
        for required in ('REACH_IOS_BUILD_NUMBER: "6"', 'test "$REACH_IOS_BUILD_NUMBER" = "6"',
                         '6153bfd1f74dcd60f1ba5fcb6cf9495b26326a17',
                         '30f8506760124f3aeb926a122d0b5353d5a2eb3c651dc8927127387a43c533c4',
                         'distribution_type: app_store', 'bundle_identifier: com.reachprototype.app',
                         'MARKETING_VERSION="0.1.0" CURRENT_PROJECT_VERSION="$REACH_IOS_BUILD_NUMBER"',
                         'native/build/build6-verified/*.ipa'):
            self.assertIn(required, workflow)
        steps = ['verify-sprint-source.py', 'install-staging-config.py --required',
                 'run-simulator-tests.sh', 'test-results build-logs/test-summary.json --expected-tests 179',
                 'xcode-project use-profiles', 'xcodebuild -exportArchive',
                 'promote-ipa build/build6-unverified build/build6-verified']
        self.assertEqual([workflow.index(step) for step in steps],
                         sorted(workflow.index(step) for step in steps))

    def test_build_six_upload_requires_an_explicit_internal_only_selection(self):
        config = (ROOT.parent/'codemagic.yaml').read_text()
        archive, upload = config.split('  reach-ios-build6-testflight:', 1)
        upload = upload.split('  reach-staging-firestore-verify:', 1)[0]
        for required in ('default: "HOLD"', 'REACH_BUILD6_MODE: testflight',
                         '${{ inputs.internal_upload }}', 'scripts: *reach_build6_scripts',
                         'artifacts: *reach_build6_artifacts', 'submit_to_testflight: false',
                         'submit_to_app_store: false'):
            self.assertIn(required, upload)
        self.assertIn('testflight) test "${REACH_BUILD6_UPLOAD_CONFIRMATION:-}" = "UPLOAD_INTERNAL_BUILD_6"', archive)
        self.assertNotIn('triggering:', upload)
        self.assertNotIn('beta_groups:', upload)
