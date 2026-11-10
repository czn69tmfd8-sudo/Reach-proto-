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
