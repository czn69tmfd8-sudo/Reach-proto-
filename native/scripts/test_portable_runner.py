import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('portable', Path(__file__).with_name('run-portable-tests.py'))
portable = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portable)


class PortableRunnerTests(unittest.TestCase):
    def test_macos_package_contains_all_selected_sources_and_tests_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            portable.write_macos_package(root)
            for group, paths in [('Sources/REACH', portable.sources), ('Tests/REACHTests', portable.tests)]:
                self.assertEqual(len(list((root / group).glob('*.swift'))), len(paths))
                for source in paths:
                    self.assertEqual((root / group / source.name).read_bytes(), source.read_bytes())
            manifest = (root / 'Package.swift').read_text()
            self.assertIn('.testTarget(name: "REACHTests", dependencies: ["REACH"]', manifest)
            self.assertIn('.swiftLanguageMode(.v6)', manifest)
            self.assertIn('.swiftLanguageMode(.v5)', manifest)
            self.assertNotIn('https://', manifest)
            self.assertFalse((root / 'main.swift').exists())

    def test_darwin_dispatches_to_swiftpm_without_legacy_xctmain(self):
        with patch.object(portable.sys, 'platform', 'darwin'), patch.object(portable.shutil, 'which', return_value='/usr/bin/swiftc'), patch.dict(portable.os.environ, {'SWIFTC': '/usr/bin/swiftc'}), patch.object(portable, 'run_macos_tests') as macos, patch.object(portable.subprocess, 'run') as direct:
            portable.main()
            macos.assert_called_once()
            direct.assert_not_called()

    def test_macos_test_failures_propagate_and_preserve_package(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            executable = root / 'toolchain/swift'; executable.parent.mkdir(); executable.write_text('fixture')
            package = root / 'package'
            failure = subprocess.CalledProcessError(1, ['swift', 'test'])
            with patch.object(portable, 'native', root / 'native'), patch.object(portable.subprocess, 'run', side_effect=failure) as run:
                with self.assertRaises(subprocess.CalledProcessError):
                    portable.run_macos_tests(package, executable.with_name('swiftc'))
            run.assert_called_once_with([str(executable), 'test', '--package-path', str(package), '--enable-xctest'], check=True)
            self.assertTrue((root / 'native/build-logs/portable-macos-failure/Package.swift').is_file())
            self.assertTrue((root / 'native/build-logs/portable-macos-failure/Tests/REACHTests').is_dir())

    def test_validation_checks_app_identity_without_reverting_runner_fix(self):
        workflow = (Path(__file__).resolve().parents[2] / 'codemagic.yaml').read_text().split('  reach-ios-validation:', 1)[1].split('  reach-ios-testflight-archive:', 1)[0]
        self.assertNotIn('git checkout', workflow)
        self.assertIn('git diff --exit-code "$REACH_VALIDATION_COMMIT" -- native/REACH native/REACHTests native/project.yml', workflow)
        for forbidden in ['publishing:', 'triggering:', 'ios_signing:', 'integrations:', 'npm test', 'emulators:exec']:
            self.assertNotIn(forbidden, workflow)
