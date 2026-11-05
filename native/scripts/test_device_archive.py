import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
spec=importlib.util.spec_from_file_location('archive',Path(__file__).with_name('verify-device-archive.py'))
archive=importlib.util.module_from_spec(spec);spec.loader.exec_module(archive)

class DeviceArchiveTests(unittest.TestCase):
    def make_app(self,t,project='reach-staging-a4745',platform='iphoneos'):
        app=Path(t)/'REACH.app';app.mkdir()
        (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.reachprototype.app','DTPlatformName':platform}))
        (app/'GoogleService-Info.plist').write_bytes(plistlib.dumps({'BUNDLE_ID':'com.reachprototype.app','PROJECT_ID':project}))
        (app/'embedded.mobileprovision').write_bytes(b'test-profile')
        return app
    def test_production_config_or_simulator_cannot_reach_signature_verification(self):
        for changes in [{'project':'reach-prototype-d70ef'},{'platform':'iphonesimulator'}]:
            with tempfile.TemporaryDirectory() as t,patch.object(archive.subprocess,'run') as command:
                with self.assertRaises(ValueError):archive.verify(self.make_app(t,**changes))
                command.assert_not_called()
    def test_simulator_identity_cannot_be_exported_as_device_build(self):
        with tempfile.TemporaryDirectory() as t,patch.object(archive.subprocess,'run',return_value=SimpleNamespace(stdout=plistlib.dumps({'application-identifier':'REACHSIM00.com.reachprototype.app'}))):
            with self.assertRaises(ValueError):archive.verify(self.make_app(t))
    def test_device_config_requires_a_valid_signature_check(self):
        with tempfile.TemporaryDirectory() as t,patch.object(archive.subprocess,'run',return_value=SimpleNamespace(stdout=plistlib.dumps({'application-identifier':'TESTTEAM00.com.reachprototype.app'}))) as command:
            archive.verify(self.make_app(t));self.assertEqual(command.call_count,2)
            self.assertIn('--verify',command.call_args.args[0])
if __name__=='__main__':unittest.main()
