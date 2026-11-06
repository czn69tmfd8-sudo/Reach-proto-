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
        self.assertNotIn('    publishing:',other)
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
