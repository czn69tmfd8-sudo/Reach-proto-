import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('source_guard', Path(__file__).with_name('verify-validation-source.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ValidationSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.write('native/REACH/App.swift', 'approved app\n')
        self.write('native/project.yml', 'approved project\n')
        self.write(guard.FIXTURE, 'fixture before\n' + guard.OLD_FIXTURE + '\nfixture after\n')
        self.write('native/REACHTests/OtherTests.swift', 'approved tests\n')
        self.git('init', '-q'); self.git('add', '.')
        self.git('-c', 'user.name=Validation fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'baseline')
        self.commit = self.git('rev-parse', 'HEAD').strip()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True)

    def write(self, path, content):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content)

    def test_unchanged_approved_source_passes(self):
        guard.verify(self.commit, self.root)

    def test_only_exact_reviewed_fixture_correction_passes(self):
        path = self.root / guard.FIXTURE
        path.write_text(path.read_text().replace(guard.OLD_FIXTURE, guard.NEW_FIXTURE))
        guard.verify(self.commit, self.root)

    def test_extra_fixture_edits_fail_closed(self):
        path = self.root / guard.FIXTURE
        path.write_text(path.read_text().replace(guard.OLD_FIXTURE, guard.NEW_FIXTURE) + '// unrelated change\n')
        with self.assertRaises(ValueError): guard.verify(self.commit, self.root)

    def test_other_test_changes_fail_closed(self):
        self.write('native/REACHTests/OtherTests.swift', 'removed an assertion\n')
        with self.assertRaises(ValueError): guard.verify(self.commit, self.root)

    def test_app_or_project_changes_fail_closed(self):
        for path in ['native/REACH/App.swift', 'native/project.yml']:
            with self.subTest(path=path):
                original = (self.root / path).read_text()
                self.write(path, 'unapproved change\n')
                with self.assertRaises(subprocess.CalledProcessError): guard.verify(self.commit, self.root)
                self.write(path, original)
