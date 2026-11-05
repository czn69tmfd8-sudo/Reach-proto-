import base64
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('config', Path(__file__).with_name('install-staging-config.py'))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)

class StagingConfigTests(unittest.TestCase):
    def encoded(self, **changes):
        data = dict(PROJECT_ID=config.PROJECT, BUNDLE_ID=config.BUNDLE, GOOGLE_APP_ID='client-app', API_KEY='client-key', GCM_SENDER_ID='123')
        data.update(changes)
        return base64.b64encode(plistlib.dumps(data)).decode()
    def test_valid_staging_file_installs_with_private_mode(self):
        with tempfile.TemporaryDirectory() as t:
            destination=Path(t)/'GoogleService-Info.plist'
            self.assertTrue(config.install(self.encoded(),destination,True))
            self.assertEqual(destination.stat().st_mode & 0o777,0o600)
    def test_production_wrong_bundle_invalid_encoding_or_missing_field_cannot_write(self):
        with tempfile.TemporaryDirectory() as t:
            destination=Path(t)/'GoogleService-Info.plist'
            for encoded in [self.encoded(PROJECT_ID='reach-prototype-d70ef'),self.encoded(BUNDLE_ID='wrong.app'),self.encoded(API_KEY=''),'not-base64']:
                with self.assertRaises(ValueError): config.install(encoded,destination,True)
                self.assertFalse(destination.exists())
    def test_absent_configuration_allowed_only_for_optional_simulator_build(self):
        with tempfile.TemporaryDirectory() as t:
            destination=Path(t)/'GoogleService-Info.plist'
            self.assertFalse(config.install(None,destination))
            with self.assertRaises(ValueError):config.install(None,destination,True)
            self.assertFalse(destination.exists())
if __name__ == '__main__': unittest.main()
