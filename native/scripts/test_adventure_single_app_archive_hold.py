from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
YAML = ROOT.parent / "codemagic.yaml"
PROJECT = ROOT / "project.yml"

class AdventureSingleAppArchiveHoldTests(unittest.TestCase):
    def workflow(self):
        source = YAML.read_text()
        start = source.index("  reach-adventure-single-app-signed-archive-hold:")
        end = source.index("\n  reach-ios-simulator:", start)
        return source[start:end]

    def test_original_identity_and_explicit_owner_hold(self):
        workflow = self.workflow()
        self.assertIn("com.reachprototype.app", workflow)
        self.assertIn('default: "UPLOAD_INTERNAL_BUILD_15"', workflow)
        self.assertIn('REACH_SIGNED_ARCHIVE_APPROVAL: ${{ inputs.archive_approval }}', workflow)
        self.assertIn('test "$REACH_IOS_BUILD_NUMBER" = "15"', workflow)
        self.assertIn('--expected-tests 207', workflow)
        self.assertLess(workflow.index('verify-sprint-source.py'), workflow.index('xcodebuild'))
        self.assertLess(workflow.index('run-simulator-tests.sh'), workflow.index('install-staging-config.py'))
        self.assertLess(workflow.index('--signing-report'), workflow.index('ditto -c -k'))
        self.assertIn('APPROVE_SINGLE_APP_ARCHIVE_ONLY', workflow)
        self.assertIn('REACH_APPLE_TEAM_ID: GFUK853ZT5', workflow)
        self.assertIn('install-staging-config.py --required', workflow)
        self.assertIn('--distribution app_store', workflow)

    def test_upload_is_gated_and_uses_existing_integration(self):
        workflow = self.workflow()
        self.assertIn('app_store_connect: REACH Codemagic', workflow)
        self.assertIn('UPLOAD_INTERNAL_BUILD_15', workflow)
        self.assertNotIn('publishing:', workflow)
        self.assertNotIn('triggering:', workflow)
        for forbidden in ('firebase deploy', 'submit_to_testflight', 'submit_to_app_store', 'beta_groups:'):
            self.assertNotIn(forbidden, workflow)
        steps = ['--expected-tests 207', '--signing-report', 'ditto -c -k',
                 'if [ "$REACH_SIGNED_ARCHIVE_APPROVAL" = "APPROVE_SINGLE_APP_ARCHIVE_ONLY" ]',
                 '-exportArchive', 'promote-ipa build/build15-unverified build/build15-verified',
                 'python3 scripts/upload-build15.py upload']
        self.assertEqual([workflow.index(x) for x in steps], sorted(workflow.index(x) for x in steps))
        self.assertIn('git diff --exit-code 04442aeba6013623f2e25dbe4caf072e5c4c829d', workflow)
        self.assertIn('native/build/build15-verified/*.ipa', workflow)
        artifacts = workflow.split('    artifacts:', 1)[1]
        self.assertNotIn('build15-unverified', artifacts)

    def test_app_identity_and_camera_microphone_permissions_unchanged(self):
        project = PROJECT.read_text()
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: com.reachprototype.app", project)
        self.assertIn("NSCameraUsageDescription", project)
        self.assertIn("NSMicrophoneUsageDescription", project)
        self.assertIn('MARKETING_VERSION: "0.1.0"', project)

if __name__ == "__main__":
    unittest.main()
