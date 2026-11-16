"""Guard the approved Adventure Book entry point and navigation without altering UI."""
from pathlib import Path
import unittest

VIEWS = Path(__file__).resolve().parents[1] / "REACH" / "Views"


class ApprovedAdventureBookIntegrationTests(unittest.TestCase):
    def test_us_opens_live_adventure_book_messenger_and_profile(self):
        us = (VIEWS / "ReachPersonalSpaceViews.swift").read_text().split("struct ReachProfilePanel")[0]
        self.assertEqual(us.count("NavigationLink"), 3)
        self.assertIn("ReachAdventureBookLive()", us)
        self.assertIn("ReachProfilePanel()", us)
        self.assertIn("ReachMessengerView()", us)
        self.assertIn('navigationCard("Our Adventure Book"', us)
        self.assertIn('navigationCard("Our Messages"', us)
        for route in ("ReachAdventureBookPreview", "ReachScrapbookView", "SharedRelationshipShelf"):
            self.assertNotIn(route, us)

    def test_sample_destination_has_no_firebase_entry_points(self):
        sample = (VIEWS / "ReachAdventureBookPreview.swift").read_text()
        for network_entry in ("import Firebase", "Firestore", "FirebaseBootstrap",
                              "ReachAdventureBookLive", "addSnapshotListener", "Auth.auth"):
            self.assertNotIn(network_entry, sample)
        for local_destination in ("AdventureLeatherCover", "gallery(spread:", "memory(at:"):
            self.assertIn(local_destination, sample)

    def test_live_authorization_rechecks_use_the_rules_protected_quota_document(self):
        repository = (VIEWS.parent / "Firebase" / "FirestoreAdventureBookRepository.swift").read_text()
        self.assertNotIn("memberLocks/", repository)
        self.assertIn("quotaDocument(code).getDocument(source: .server)", repository)
        self.assertIn("try await self.verifiedCode(pairCode)", repository)
        self.assertIn("accessRecheckTask?.cancel()", repository)

    def test_live_write_callbacks_do_not_inherit_the_main_actor(self):
        firebase = VIEWS.parent / "Firebase"
        for name, count in (("FirestoreAdventureBookRepository.swift", 2),
                            ("FirestoreAdventureStoryTransport.swift", 1),
                            ("FirestoreAdventurePhotoTransport.swift", 1)):
            source = (firebase / name).read_text()
            self.assertEqual(source.count("db.runTransaction({ @Sendable"), count)
            self.assertEqual(source.count("db.runTransaction"), count)
            self.assertEqual(source.count("completion: { @Sendable _, error in"), count)

    def test_cover_gallery_memory_navigation_and_return(self):
        live = (VIEWS / "ReachAdventureBookLive.swift").read_text()
        self.assertIn("AdventureBookPageFrame()", live)
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
