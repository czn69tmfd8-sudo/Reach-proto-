import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('sprint_source', Path(__file__).with_name('verify-sprint-source.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

ROOT = Path(__file__).resolve().parents[2]
APPROVED = 'c67f05b4440fe2dcdfdd5746779cb176a6f213ea2acb2dbb870a214ebc60eb1e'


class SprintSourceTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        self.inputs = [
            'native/REACH/App.swift',
            'native/REACHTests/AppTests.swift',
            'native/Configuration/Simulator.entitlements',
            'native/project.yml',
        ]
        for path in self.inputs:
            self.write(path, 'approved\n')
        self.write('.gitignore', 'Ignored.swift\n')
        self.git('init', '-q')
        self.commit()
        tree = subprocess.check_output(['git', 'ls-tree', '-rz', 'HEAD', '--', *guard.SOURCE_PATHS], cwd=self.root)
        self.approved = hashlib.sha256(tree).hexdigest()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True, stderr=subprocess.PIPE)

    def write(self, path, content):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)

    def commit(self):
        self.git('add', '.')
        self.git('-c', 'user.name=Source fixture', '-c', 'user.email=fixture@example.invalid',
                 'commit', '-qm', 'fixture')

    def test_ci_only_descendant_can_validate_approved_inputs(self):
        self.write('codemagic.yaml', 'CI fix\n')
        self.commit()
        guard.verify(self.approved, self.root)

    def test_committed_source_change_fails_even_if_working_bytes_are_restored(self):
        self.write(self.inputs[0], 'new application\n')
        self.commit()
        self.write(self.inputs[0], 'approved\n')
        with self.assertRaisesRegex(ValueError, 'Committed sprint source differs'):
            guard.verify(self.approved, self.root)

    def test_working_source_changes_fail_in_every_protected_scope(self):
        for path in self.inputs:
            with self.subTest(path=path):
                self.write(path, 'changed\n')
                with self.assertRaisesRegex(ValueError, 'Working source differs'):
                    guard.verify(self.approved, self.root)
                self.write(path, 'approved\n')

    def test_assume_unchanged_flag_does_not_hide_edited_source(self):
        self.git('update-index', '--assume-unchanged', self.inputs[0])
        self.write(self.inputs[0], 'hidden edit\n')
        with self.assertRaisesRegex(ValueError, 'Working source differs'):
            guard.verify(self.approved, self.root)

    def test_ignored_and_untracked_additions_are_rejected(self):
        for name in ('Ignored.swift', 'Extra.swift'):
            with self.subTest(name=name):
                relative = f'native/REACH/{name}'
                self.write(relative, 'extra source\n')
                with self.assertRaisesRegex(ValueError, 'Unexpected source entry'):
                    guard.verify(self.approved, self.root)
                (self.root / relative).unlink()

    def test_removed_and_symlinked_source_are_rejected(self):
        path = self.root / self.inputs[0]
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'Approved source is missing'):
            guard.verify(self.approved, self.root)
        self.write('replacement.swift', 'approved\n')
        path.symlink_to(self.root / 'replacement.swift')
        with self.assertRaisesRegex(ValueError, 'Unexpected source entry'):
            guard.verify(self.approved, self.root)

    def test_incorrect_approved_fingerprint_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Committed sprint source differs'):
            guard.verify('0' * 64, self.root)

    def test_sprint_workflow_enforces_fixed_pin_before_build_steps(self):
        workflow = (ROOT / 'codemagic.yaml').read_text()
        sprint = workflow.split('  reach-ios-sprint-validation:', 1)[1].split('  reach-ios-testflight-archive:', 1)[0]
        command = f'python3 native/scripts/verify-sprint-source.py {APPROVED}'
        first_step = sprint.split('      - name: ', 2)[1]
        self.assertIn('\n          set -euo pipefail\n', first_step)
        self.assertIn(f'\n          {command}\n', first_step)
        self.assertLess(sprint.index(command), sprint.index('python3 -m unittest'))
        self.assertNotIn('verify-validation-source.py', sprint)
