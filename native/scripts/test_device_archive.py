import importlib.util
from pathlib import Path
from datetime import datetime, timezone, timedelta
from copy import deepcopy
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
    def signing_data(self):
        entitlements={'application-identifier':'TESTTEAM00.com.reachprototype.app',
          'com.apple.developer.team-identifier':'TESTTEAM00','get-task-allow':False}
        profile={'ExpirationDate':datetime(2030,1,1), 'TeamIdentifier':['TESTTEAM00'],
          'Entitlements':deepcopy(entitlements),'ProvisionedDevices':['test-device-udid']}
        return entitlements,profile
    def test_device_config_requires_profile_and_signature_checks(self):
        entitlements,profile=self.signing_data()
        with tempfile.TemporaryDirectory() as t,patch.object(archive.subprocess,'run',side_effect=[
            SimpleNamespace(stdout=plistlib.dumps(entitlements)),
            SimpleNamespace(stdout=plistlib.dumps(profile)), SimpleNamespace(stdout=b'')]) as command:
            archive.verify(self.make_app(t));self.assertEqual(command.call_count,3)
            self.assertEqual(command.call_args_list[1].args[0][:3],['security','cms','-D'])
            self.assertIn('--verify',command.call_args.args[0])
    def test_expired_or_missing_profile_expiry_rejected(self):
        e,p=self.signing_data();now=datetime(2030,1,1,tzinfo=timezone.utc)
        for expiry in [None,now.replace(tzinfo=None),now.replace(tzinfo=None)-timedelta(seconds=1)]:
            with self.subTest(expiry=expiry),self.assertRaises(ValueError):
                archive.validate_profile(dict(p,ExpirationDate=expiry),e,now)
    def test_wrong_team_or_wildcard_app_rejected(self):
        e,p=self.signing_data()
        for field,value in [('TeamIdentifier',['OTHERTEAM0']),('application-identifier','TESTTEAM00.*'),
                            ('com.apple.developer.team-identifier','OTHERTEAM0')]:
            modified=deepcopy(p)
            if field=='TeamIdentifier':modified[field]=value
            else:modified['Entitlements'][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):archive.validate_profile(modified,e)
    def test_store_enterprise_or_development_profile_rejected(self):
        e,p=self.signing_data()
        for field,value in [('ProvisionedDevices',[]),('ProvisionedDevices',None),
                            ('ProvisionedDevices',['']),('ProvisionsAllDevices',True)]:
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):
                archive.validate_profile(dict(p,**{field:value}),e)
        for target in ['app','profile']:
            changed_e,changed_p=deepcopy(e),deepcopy(p)
            (changed_e if target=='app' else changed_p['Entitlements'])['get-task-allow']=True
            with self.subTest(target=target),self.assertRaises(ValueError):archive.validate_profile(changed_p,changed_e)
    def test_unexpired_exact_ad_hoc_profile_accepted(self):
        e,p=self.signing_data();archive.validate_profile(p,e,datetime(2029,1,1,tzinfo=timezone.utc))
if __name__=='__main__':unittest.main()
