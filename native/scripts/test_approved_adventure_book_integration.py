"""Guard the approved Adventure Book entry point and navigation without altering UI."""
from pathlib import Path
import unittest

VIEWS = Path(__file__).resolve().parents[1] / "REACH" / "Views"


class ApprovedAdventureBookIntegrationTests(unittest.TestCase):
    def test_us_section_opens_approved_live_book(self):
        us = (VIEWS / "ReachPersonalSpaceViews.swift").read_text()
        self.assertIn('case scrapbook = "Our Adventure Book"', us)
        self.assertIn("NavigationLink {\n                    ReachAdventureBookLive()", us)
        self.assertIn("AdventureLeatherArtwork()", us)

    def test_cover_gallery_memory_navigation_and_return(self):
        live = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        self.assertIn("AdventureLeatherCover {", live)
        self.assertIn("page = 1", live)
        self.assertIn("galleryPage(Array(ordered[AdventureGalleryPagination.memoryRange", live)
        self.assertIn("memoryPage(memory)", live)
        self.assertIn("openedMemoryID = memory.id", live)
        self.assertIn("forSelectedMemoryID: memory.id", live)
        self.assertIn('Button("Previous")', live)
        self.assertIn('Button("Next")', live)

    def test_live_book_preserves_shared_data_and_approved_artwork(self):
        live = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        components = (VIEWS / "AdventureBookVisualComponents.swift").read_text()
        for name in ("FirestoreAdventureBookRepository()", "repository.observe(",
                     "AdventureParchmentPage", "AdventureGalleryHeading",
                     "AdventureMountedFrame", "AdventureStoryCard",
                     "AdventureAuthenticatedPhoto"):
            self.assertIn(name, live)
        for name in ("AdventureArtwork.image(0)", "AdventureArtwork.image(1)",
                     "SnellRoundhand", "Noteworthy-Light", "Baskerville",
                     "Color.olive"):
            self.assertIn(name, components)
