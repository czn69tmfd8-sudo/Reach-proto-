import importlib.util
from pathlib import Path
from copy import deepcopy
import unittest

spec=importlib.util.spec_from_file_location('store',Path(__file__).with_name('prepare-store-export.py'))
store=importlib.util.module_from_spec(spec);spec.loader.exec_module(store)

class StoreExportTests(unittest.TestCase):
    def options(self):
        return {'method':'app-store-connect','teamID':'TESTTEAM00','provisioningProfiles':{'com.reachprototype.app':'staging-profile'},'destination':'export','uploadSymbols':False,'testFlightInternalTestingOnly':True,'manageAppVersionAndBuildNumber':False}
    def test_explicit_real_team_and_unused_build_input_required(self):
        self.assertEqual(store.inputs({'REACH_APPLE_TEAM_ID':'TESTTEAM00','REACH_IOS_BUILD_NUMBER':'12'}),('TESTTEAM00','12'))
        for patch in [{'REACH_APPLE_TEAM_ID':''},{'REACH_APPLE_TEAM_ID':'short'},{'REACH_IOS_BUILD_NUMBER':'0'},{'REACH_IOS_BUILD_NUMBER':'1; upload'},{'REACH_IOS_BUILD_NUMBER':'10000'}]:
            with self.subTest(patch=patch),self.assertRaises(ValueError):store.inputs({'REACH_APPLE_TEAM_ID':'TESTTEAM00','REACH_IOS_BUILD_NUMBER':'12',**patch})
    def test_store_only_exact_bundle_team_and_local_export(self):
        store.validate_export(self.options(),'TESTTEAM00')
        for patch in [{'method':'ad-hoc'},{'method':'development'},{'teamID':'OTHERTEAM0'},{'destination':'upload'},{'uploadSymbols':True},{'testFlightInternalTestingOnly':False},{'manageAppVersionAndBuildNumber':True},{'provisioningProfiles':{'other.bundle':'profile'}},{'provisioningProfiles':{}}]:
            with self.subTest(patch=patch),self.assertRaises(ValueError):store.validate_export({**self.options(),**patch},'TESTTEAM00')
    def test_extra_app_profile_cannot_be_exported(self):
        options=deepcopy(self.options());options['provisioningProfiles']['other.app']='profile'
        with self.assertRaises(ValueError):store.validate_export(options,'TESTTEAM00')
    def test_missing_or_ambiguous_ipa_cannot_pass(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):store.verify_ipa(folder,'TESTTEAM00','12')
            for name in ['first.ipa','second.ipa']:(Path(folder)/name).write_bytes(b'')
            with self.assertRaises(ValueError):store.verify_ipa(folder,'TESTTEAM00','12')

    def test_unsafe_ipa_paths_are_rejected_before_extraction(self):
        import tempfile,zipfile
        for name in ['../outside','/absolute']:
            with tempfile.TemporaryDirectory() as folder:
                with zipfile.ZipFile(Path(folder)/'app.ipa','w') as package:package.writestr(name,b'bad')
                with self.subTest(name=name),self.assertRaises(ValueError):store.verify_ipa(folder,'TESTTEAM00','12')

    def test_failed_verification_never_promotes_publishable_ipa(self):
        import tempfile
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as folder:
            destination=Path(folder)/'published'
            with patch.object(store,'verify_ipa',side_effect=ValueError('bad signature')):
                with self.assertRaises(ValueError):store.promote_ipa(folder,destination,'TESTTEAM00','12')
            self.assertFalse(destination.exists())
    def test_verified_ipa_is_promoted_once_and_cannot_overwrite(self):
        import tempfile
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'source';source.mkdir()
            (source/'app.ipa').write_bytes(b'verified archive')
            destination=Path(folder)/'published'
            with patch.object(store,'verify_ipa') as verify:
                store.promote_ipa(source,destination,'TESTTEAM00','12')
                verify.assert_called_once_with(source,'TESTTEAM00','12')
                self.assertEqual((destination/'app.ipa').read_bytes(),b'verified archive')
                with self.assertRaises(ValueError):store.promote_ipa(source,destination,'TESTTEAM00','12')

    def test_release_version_build_number_and_compiled_images_are_required(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            app=Path(folder)
            info={'CFBundleVersion':'2','CFBundleShortVersionString':'0.1.0'}
            with self.assertRaises(ValueError):store.validate_release_resources(app,info,'2')
            (app/'Assets.car').write_bytes(b'')
            with self.assertRaises(ValueError):store.validate_release_resources(app,info,'2')
            (app/'Assets.car').write_bytes(b'compiled assets')
            store.validate_release_resources(app,info,'2')
            for patch in [{'CFBundleVersion':'1'},{'CFBundleShortVersionString':'0.2.0'}]:
                with self.subTest(patch=patch),self.assertRaises(ValueError):
                    store.validate_release_resources(app,{**info,**patch},'2')
