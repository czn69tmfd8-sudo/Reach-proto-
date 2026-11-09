import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('staging_auth', Path(__file__).with_name('check-staging-auth.py'))
auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auth)

class StagingAuthTests(unittest.TestCase):
    config = {'PROJECT_ID': auth.PROJECT, 'BUNDLE_ID': auth.BUNDLE, 'API_KEY': 'test-client-key', 'GCM_SENDER_ID': auth.PROJECT_NUMBER, 'GOOGLE_APP_ID': f'1:{auth.PROJECT_NUMBER}:ios:test'}
    def fixture(self, project=auth.PROJECT, lookup_error=False, cleanup_error=False):
        calls = []
        def transport(method, url, payload=None):
            calls.append((method, url, payload))
            if '/projects?' in url: return {'projectId': project, 'authorizedDomains': [f'{auth.PROJECT}.firebaseapp.com']}
            if 'signUp' in url: return {'idToken': 'ephemeral-token', 'localId': 'new-test-user'}
            if 'lookup' in url:
                if lookup_error: raise auth.CheckError('LOOKUP_FAILED')
                return {'users': [{'localId': 'new-test-user'}]}
            if 'delete' in url:
                if cleanup_error: raise auth.CheckError('DELETE_FAILED')
                return {}
            raise AssertionError('Unexpected request')
        return calls, transport
    def test_rejects_production_configuration_before_any_request(self):
        calls, transport = self.fixture()
        with self.assertRaisesRegex(auth.CheckError, 'MISMATCH'):
            auth.check_auth(dict(self.config, PROJECT_ID='reach-prototype-d70ef'), transport)
        self.assertEqual(calls, [])
    def test_rejects_a_mislabeled_production_api_key_before_any_write(self):
        calls, transport = self.fixture(project='reach-prototype-d70ef')
        with self.assertRaisesRegex(auth.CheckError, 'NO_USER_CREATED'): auth.check_auth(self.config, transport)
        self.assertEqual([c[0] for c in calls], ['GET'])
    def test_numeric_project_response_must_match_approved_number_app_and_domain(self):
        calls, transport = self.fixture(project=auth.PROJECT_NUMBER)
        self.assertEqual(auth.check_auth(self.config, transport)['anonymousAuth'], 'verified')
        calls, transport = self.fixture(project=auth.PROJECT_NUMBER)
        with self.assertRaisesRegex(auth.CheckError, 'NO_USER_CREATED'):
            auth.check_auth(dict(self.config, GCM_SENDER_ID='wrong'), transport)
        self.assertEqual([c[0] for c in calls], ['GET'])
    def test_success_creates_verifies_and_cleans_only_its_new_account(self):
        calls, transport = self.fixture()
        self.assertEqual(auth.check_auth(self.config, transport)['temporaryAccountCleanup'], 'verified')
        self.assertEqual(len(calls), 4)
        self.assertEqual(calls[-1][2], {'idToken': 'ephemeral-token'})
    def test_lookup_failure_still_cleans_new_test_account(self):
        calls, transport = self.fixture(lookup_error=True)
        with self.assertRaisesRegex(auth.CheckError, 'LOOKUP_FAILED'): auth.check_auth(self.config, transport)
        self.assertIn('accounts:delete', calls[-1][1])
    def test_cleanup_failure_cannot_be_reported_as_success(self):
        _, transport = self.fixture(cleanup_error=True)
        with self.assertRaisesRegex(auth.CheckError, 'CLEANUP_NOT_CONFIRMED'): auth.check_auth(self.config, transport)

if __name__ == '__main__': unittest.main()
