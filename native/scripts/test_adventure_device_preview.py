import base64
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

MODULE = Path(__file__).with_name("prepare-adventure-device-preview.py")
spec = importlib.util.spec_from_file_location("preview", MODULE)
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)

class AdventureDevicePreviewTests(unittest.TestCase):
    def fixture(self, root):
        root = Path(root)
        (root / "REACH/Firebase").mkdir(parents=True)
        (root / "project.yml").write_text(
            "PRODUCT_BUNDLE_IDENTIFIER: com.reachprototype.app\n"
            "INFOPLIST_KEY_CFBundleDisplayName: REACH Staging\n"
            '"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]": Configuration/Simulator.entitlements\n')
        (root / "REACH/Firebase/ReachEnvironment.swift").write_text(
            "guard configuredBundleID == nativeBundleID, runningBundleID == nativeBundleID else {\n")
        return root

    def test_overlay_uses_distinct_bundle_and_simulator_entitlements(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            entitlements = preview.prepare(root)
            project = (root / "project.yml").read_text()
            self.assertIn(preview.PREVIEW, project)
            self.assertNotIn("PRODUCT_BUNDLE_IDENTIFIER: " + preview.ORIGINAL, project)
            self.assertIn(preview.APP_NAME, project)
            self.assertIn(preview.ENTITLEMENTS, project)
            plist = plistlib.loads(entitlements.read_bytes())
            self.assertEqual(plist["keychain-access-groups"], ["REACHSIM00." + preview.PREVIEW])
            self.assertIn("nativeBundleID", (root / "REACH/Firebase/ReachEnvironment.swift").read_text())
            with self.assertRaises(ValueError):
                preview.prepare(root)

    def test_config_requires_dedicated_firebase_app_and_correct_bucket(self):
        with tempfile.TemporaryDirectory() as directory:
            dest = Path(directory) / "GoogleService-Info.plist"
            config = dict(PROJECT_ID=preview.PROJECT, BUNDLE_ID=preview.PREVIEW,
                          STORAGE_BUCKET=preview.BUCKET, GOOGLE_APP_ID="app",
                          API_KEY="key", GCM_SENDER_ID="123")
            for key, value in [("PROJECT_ID", "reach-prototype-d70ef"),
                               ("BUNDLE_ID", preview.ORIGINAL),
                               ("STORAGE_BUCKET", "other.appspot.com")]:
                wrong = dict(config, **{key: value})
                with self.assertRaises(ValueError):
                    preview.install_preview_config(base64.b64encode(plistlib.dumps(wrong)).decode(), dest)
                self.assertFalse(dest.exists())
            preview.install_preview_config(base64.b64encode(plistlib.dumps(config)).decode(), dest)
            self.assertEqual(dest.stat().st_mode & 0o777, 0o600)

    def test_no_production_or_distribution_actions(self):
        source = MODULE.read_text()
        for forbidden in ("firebase deploy", "app_store_connect:", "xcode-project use-profiles",
                          "reach-prototype-d70ef", "testflight", "REACH_BUILD6_UPLOAD_CONFIRMATION"):
            self.assertNotIn(forbidden, source)

if __name__ == "__main__":
    unittest.main()
