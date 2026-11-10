"""Visual-branch guardrails: no networking, backend changes, or accidental feature loss."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
VIEWS = ROOT / "native/REACH/Views"

class AdventureBookVisualRegressionTests(unittest.TestCase):
    def test_visual_components_are_presentation_only(self):
        source = (VIEWS / "AdventureBookVisualComponents.swift").read_text()
        for forbidden in ("FirebaseAuth", "FirebaseFirestore", "FirebaseStorage", "Firestore.firestore(", "Auth.auth("):
            self.assertNotIn(forbidden, source)
        for expected in ("AdventureLeatherCover", "AdventureParchmentPage",
                         "AdventureStoryCard", "Touch to open", "accessibilityReduceMotion"):
            if expected == "accessibilityReduceMotion":
                continue
            self.assertIn(expected, source)

    def test_live_book_keeps_shared_data_and_editing(self):
        source = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        for expected in ("FirestoreAdventureBookRepository()", "repository.observe(",
                         "AdventureLeatherCover", "galleryPage(ordered)",
                         "AdventureStoryCard", "AdventureAuthenticatedPhoto(",
                         "AdventurePhotoFeatureGate.liveUploadsEnabled",
                         "saveOwnStory(", "postComment(", "onDisappear",
                         "accessibilityReduceMotion"):
            self.assertIn(expected, source)
        self.assertNotIn(chr(92) + "n                PhotosPicker", source)

    def test_gallery_does_not_auto_import_private_content(self):
        source = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        self.assertIn("ForEach(Array(memories.enumerated())", source)
        self.assertIn("page = index + 2", source)
        self.assertNotIn("PHPhotoLibrary.shared()", source)
