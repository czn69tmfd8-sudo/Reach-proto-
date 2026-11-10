from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
YAML = ROOT.parent / "codemagic.yaml"
PROJECT = ROOT / "project.yml"

class AdventureSingleAppArchiveHoldTests(unittest.TestCase):
    def workflow(self):
        source = YAML.read_text()
        start = source.index("  reach-adventure-single-app-signed-archive-hold:")
        end = source.index("\n  reach-ios-device:", start)
        return source[start:end]

    def test_original_identity_and_explicit_owner_hold(self):
        workflow = self.workflow()
        self.assertIn("com.reachprototype.app", workflow)
        self.assertIn('REACH_SIGNED_ARCHIVE_APPROVAL: HOLD', workflow)
        self.assertIn('APPROVE_SINGLE_APP_ARCHIVE_ONLY', workflow)
        self.assertIn('REACH_APPLE_TEAM_ID: GFUK853ZT5', workflow)
        self.assertIn('install-staging-config.py --required', workflow)
        self.assertIn('--distribution app_store', workflow)

    def test_no_upload_ipa_export_or_deployment(self):
        workflow = self.workflow()
        for forbidden in ("-exportArchive", "publishing:", "app_store_connect:", "firebase deploy",
                          "submit_to_testflight", "build/ios/ipa", "distribution_type: ad_hoc"):
            self.assertNotIn(forbidden, workflow)
        self.assertIn("REACH-AdventureBook.xcarchive", workflow)
        self.assertIn("CURRENT_PROJECT_VERSION=", workflow)

    def test_app_identity_and_camera_microphone_permissions_unchanged(self):
        project = PROJECT.read_text()
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: com.reachprototype.app", project)
        self.assertIn("NSCameraUsageDescription", project)
        self.assertIn("NSMicrophoneUsageDescription", project)
        self.assertIn('MARKETING_VERSION: "0.1.0"', project)

if __name__ == "__main__":
    unittest.main()
