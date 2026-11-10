import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('upload15', Path(__file__).with_name('upload-build15.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Build15UploadTests(unittest.TestCase):
    def env(self):
        return {'CM_BRANCH': 'feature/adventure-book-single-app-integration',
                'REACH_SIGNED_ARCHIVE_APPROVAL': 'UPLOAD_INTERNAL_BUILD_15',
                'REACH_APPLE_TEAM_ID': 'GFUK853ZT5', 'REACH_IOS_BUILD_NUMBER': '15',
                **{k: 'test-placeholder' for k in module.CREDENTIALS}}

    def test_hold_archive_wrong_identity_and_pr_cannot_upload(self):
        for change in ({'REACH_SIGNED_ARCHIVE_APPROVAL': 'HOLD'},
                       {'REACH_SIGNED_ARCHIVE_APPROVAL': 'APPROVE_SINGLE_APP_ARCHIVE_ONLY'},
                       {'CM_BRANCH': 'native-reach'}, {'REACH_IOS_BUILD_NUMBER': '7'},
                       {'REACH_APPLE_TEAM_ID': 'OTHERTEAM0'}, {'CM_PULL_REQUEST_DEST': 'main'}):
            with self.subTest(change=change), patch.object(module.subprocess, 'run') as run:
                with self.assertRaises(ValueError):
                    module.upload('/not-used', {**self.env(), **change})
                run.assert_not_called()

    def test_missing_credentials_fail_before_any_apple_command(self):
        for key in module.CREDENTIALS:
            env = self.env(); env.pop(key)
            with self.subTest(key=key), self.assertRaises(ValueError):
                module.preflight(env)

    def test_only_exact_verified_ipa_and_no_external_or_public_flags(self):
        with tempfile.TemporaryDirectory() as folder:
            ipa = Path(folder) / 'REACH.ipa'; ipa.touch()
            env = {**self.env(), 'APP_STORE_CONNECT_SUBMIT_TO_TESTFLIGHT': 'true',
                   'APP_STORE_CONNECT_SUBMIT_TO_APP_STORE': 'true',
                   'APP_STORE_CONNECT_BETA_GROUPS': 'External',
                   'APP_STORE_CONNECT_ALTOOL_ADDITIONAL_ARGUMENTS': 'unexpected',
                   'APP_SPECIFIC_PASSWORD': 'test-placeholder', 'PATH': os.environ['PATH']}
            with patch.object(module.subprocess, 'run') as run:
                result = module.upload(folder, env)
            args, kwargs = run.call_args
            self.assertEqual(args[0], ['app-store-connect', 'publish', '--path', str(ipa), '--enable-package-validation'])
            self.assertEqual({k for k in kwargs['env'] if k.startswith('APP_STORE_CONNECT_')}, module.CREDENTIALS)
            self.assertNotIn('APP_SPECIFIC_PASSWORD', kwargs['env'])
            self.assertTrue(kwargs['check'])
            self.assertEqual(result['processingStatus'], 'not_yet_verified')

    def test_zero_or_multiple_ipa_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError): module.upload(folder, self.env())
            (Path(folder)/'one.ipa').touch(); (Path(folder)/'two.ipa').touch()
            with self.assertRaises(ValueError): module.upload(folder, self.env())

    def test_failed_upload_does_not_return_success(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/'REACH.ipa').touch()
            with patch.object(module.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'publish')):
                with self.assertRaises(subprocess.CalledProcessError):
                    module.upload(folder, self.env())
