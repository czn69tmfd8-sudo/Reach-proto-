import importlib.util
from pathlib import Path
import tempfile
import unittest
import json

MODULE = Path(__file__).with_name("prepare-adventure-emulator-config.py")
spec = importlib.util.spec_from_file_location("adventure_emulator", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class AdventureEmulatorConfigurationTests(unittest.TestCase):
    def fixture(self, root):
        root = Path(root)
        (root / module.FIRESTORE).write_text(
            "rules_version = '2';\nservice cloud.firestore { match /databases/{database}/documents { match /{x=**} { allow read, write: if false; } } }")
        (root / module.STORAGE).write_text(
            "rules_version = '2';\nservice firebase.storage { match /b/{bucket}/o { match /{x=**} { allow read, write: if false; } } }")
        return root

    def test_explicit_local_rules_and_both_emulators(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            config = json.loads(module.prepare(root).read_text())
            self.assertEqual(config["firestore"]["rules"], module.FIRESTORE)
            self.assertEqual(config["storage"]["rules"], module.STORAGE)
            self.assertEqual(config["emulators"]["firestore"]["port"], 8080)
            self.assertEqual(config["emulators"]["storage"]["port"], 9199)
            self.assertEqual(config["emulators"]["firestore"]["host"], "127.0.0.1")
            self.assertEqual(config["emulators"]["storage"]["host"], "127.0.0.1")

    def test_missing_or_invalid_rules_fail_before_emulator_start(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            for filename in (module.FIRESTORE, module.STORAGE):
                path = root / filename
                original = path.read_text()
                path.unlink()
                with self.assertRaises(RuntimeError):
                    module.prepare(root)
                path.write_text("rules_version = '2';\n")
                with self.assertRaises(RuntimeError):
                    module.prepare(root)
                path.write_text(original)

    def test_no_production_or_deployment_commands(self):
        source = MODULE.read_text()
        self.assertNotIn("firebase deploy", source)
        self.assertNotIn("reach-staging-a4745", source)
        self.assertNotIn("reach-prototype-d70ef", source)

if __name__ == "__main__":
    unittest.main()
