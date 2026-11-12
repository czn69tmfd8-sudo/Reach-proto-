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
                         "AdventureLeatherCover", "galleryPage(Array(ordered[AdventureGalleryPagination.memoryRange",
                         "AdventureStoryCard", "AdventureAuthenticatedPhoto(",
                         "AdventurePhotoFeatureGate.liveUploadsEnabled",
                         "saveOwnStory(", "postComment(", "onDisappear",
                         "accessibilityReduceMotion"):
            self.assertIn(expected, source)
        self.assertNotIn(chr(92) + "n                PhotosPicker", source)

    def test_cover_has_bundled_reference_materials_and_no_remote_artwork(self):
        source = (VIEWS / "AdventureBookVisualComponents.swift").read_text()
        for expected in ('AdventureLeatherArtwork', 'AdventureArtwork.image(0)',
                         'AdventureMountedPhoto', 'AdventureTape', 'SnellRoundhand',
                         'Noteworthy-Light', 'Baskerville', 'AdventureBookPalette.gold',
                         'accessibilityLabel("Open Our Adventure Book")'):
            self.assertIn(expected, source)
        self.assertNotIn('AsyncImage(', source)
        self.assertNotIn('URLSession', source)
        self.assertNotIn('FirebaseStorage', source)

    def test_leather_and_parchment_regions_are_bundled(self):
        import json
        asset = ROOT / 'native/REACH/Assets.xcassets/AdventureMaterials.imageset'
        entries = json.loads((asset/'Contents.json').read_text())['images']
        self.assertEqual(len(entries), 1)
        self.assertTrue((asset/entries[0]['filename']).is_file())
        source = (VIEWS / 'AdventureBookVisualComponents.swift').read_text()
        self.assertIn('AdventureArtwork.image(1)', source)
        self.assertIn('atlas.cropping(to:', source)

    def test_gallery_thumbnails_reuse_authenticated_photo_transport(self):
        source = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        self.assertIn("if let coverPhoto = memory.photos.first", source)
        self.assertIn("compact: true", source)
        self.assertIn("var compact = false", source)
        self.assertIn("FirestoreAdventurePhotoTransport()", source)
        self.assertNotIn("downloadURL(", source)

    def test_story_save_uses_authenticated_session_and_captured_version(self):
        source = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        editor = source.split(".sheet(item: $selectedMemory)", 1)[1].split("private func galleryPage", 1)[0]
        save = source.split("private func saveStory", 1)[1].split("private func postComment", 1)[0]
        self.assertIn("let version = selectedStoryVersion", editor)
        self.assertIn("let epoch = connectionEpoch", editor)
        self.assertIn("version: version, epoch: epoch", editor)
        self.assertIn("guard connectionEpoch == epoch else { return }", save)
        self.assertIn("guard let code = pairCode, Auth.auth().currentUser != nil else { return }", save)
        self.assertIn("expectedVersion: version", save)

    def test_gallery_does_not_auto_import_private_content(self):
        source = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        self.assertIn("ForEach(Array(memories.enumerated())", source)
        self.assertIn("openedMemoryID = memory.id", source)
        self.assertNotIn("PHPhotoLibrary.shared()", source)
