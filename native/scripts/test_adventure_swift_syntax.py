"""Guard new native Adventure Book Swift sources against escaped key-path syntax."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class AdventureBookSwiftSyntaxGuards(unittest.TestCase):
    def test_no_doubly_escaped_swift_key_paths(self):
        files = list((ROOT / "native/REACH").rglob("*.swift"))
        self.assertTrue(files)
        for path in files:
            if "Adventure" not in path.name and "Photo" not in path.name:
                continue
            source = path.read_text()
            with self.subTest(path=str(path.relative_to(ROOT))):
                # A Swift key path uses one backslash, e.g. map(\\.id).
                # A second backslash is a syntax error (not string escaping).
                self.assertNotIn(chr(92) * 2 + ".", source)

    def test_storage_download_uses_bounded_callback_bridge(self):
        source = (ROOT / "native/REACH/Firebase/FirestoreAdventurePhotoTransport.swift").read_text()
        self.assertIn("reference.getData(maxSize: maxSize, completion: completion)", source)
        self.assertIn("withCheckedThrowingContinuation", source)
        self.assertIn("withTaskCancellationHandler", source)
        self.assertIn("guard maxSize > 0, maxSize <= 15_728_640", source)
        self.assertNotIn(".getData(maxSize: maximumBytes)", source)
        self.assertNotIn("try await object.getData(", source)
        self.assertIn("guard !finished else", source)
