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

    def test_firestore_transactions_remain_atomic_callback_operations(self):
        for name in ("FirestoreAdventureStoryTransport.swift",
                     "FirestoreAdventureBookRepository.swift",
                     "FirestoreAdventurePhotoTransport.swift"):
            source = (ROOT / "native/REACH/Firebase" / name).read_text()
            with self.subTest(file=name):
                self.assertIn("db.runTransaction({", source)
                self.assertIn("withCheckedThrowingContinuation", source)
                self.assertNotIn("try await db.runTransaction", source)

    def test_photo_sdk_calls_do_not_cross_actor_as_async_references(self):
        source = (ROOT / "native/REACH/Firebase/FirestoreAdventurePhotoTransport.swift").read_text()
        self.assertIn("object.getMetadata {", source)
        self.assertIn("object.putData(bytes, metadata: metadata)", source)
        self.assertNotIn("try await object.getMetadata()", source)
        self.assertNotIn("try await object.putDataAsync", source)

    def test_storage_metadata_crosses_continuation_as_sendable_snapshot(self):
        source = (ROOT / "native/REACH/Firebase/FirestoreAdventurePhotoTransport.swift").read_text()
        self.assertIn("private struct AdventureRemotePhotoMetadata: Sendable", source)
        for field in ("ownerUID", "sha256", "size", "contentType", "name", "bucket", "generation"):
            self.assertIn("let " + field + ":", source)
        self.assertIn("continuation.resume(returning: snapshot)", source)
        self.assertNotIn("continuation.resume(returning: metadata)", source)
        self.assertNotIn("async throws -> StorageMetadata", source)

    def test_storage_generation_matches_firebase_int64(self):
        source = (ROOT / "native/REACH/Firebase/FirestoreAdventurePhotoTransport.swift").read_text()
        self.assertIn("let generation: Int64", source)
        self.assertIn("generation: metadata.generation", source)
        self.assertNotIn("let generation: String?", source)
        self.assertIn("remote.name == upload.photoID", source)
        self.assertIn("remote.bucket == object.bucket", source)
        self.assertIn("SHA256.hash(data: remoteBytes) == SHA256.hash(data: bytes)", source)
