import unittest
from memory_policy import (
    Action, Membership, Memory, can_access, valid_photo, valid_story, valid_message,
    MAX_PHOTO_BYTES, MAX_STORY_CHARS, MAX_MESSAGE_CHARS,
)

NOW = 1000


class MemoryPolicyTests(unittest.TestCase):
    def setUp(self):
        self.alice = Membership("alice", "pair1", True, expires_at=2000)
        self.bob = Membership("bob", "pair1", True, expires_at=2000)
        self.mallory = Membership("mallory", "pair2", True, expires_at=2000)
        self.memory = Memory("pair1", "alice", 4)

    def test_partner_reads(self):
        self.assertTrue(can_access(self.bob, self.memory, Action.READ, NOW))

    def test_cross_pair_denied(self):
        for action in Action:
            self.assertFalse(can_access(self.mallory, self.memory, action, NOW, expected_version=4))

    def test_unpaired_denied(self):
        self.assertFalse(can_access(None, self.memory, Action.READ, NOW))

    def test_revoked_denied(self):
        revoked = Membership("alice", "pair1", True, revoked=True, expires_at=2000)
        for action in Action:
            self.assertFalse(can_access(revoked, self.memory, action, NOW, expected_version=4))

    def test_expired_denied(self):
        expired = Membership("alice", "pair1", True, expires_at=NOW)
        self.assertFalse(can_access(expired, self.memory, Action.READ, NOW))

    def test_inactive_denied(self):
        inactive = Membership("alice", "pair1", False, expires_at=2000)
        self.assertFalse(can_access(inactive, self.memory, Action.READ, NOW))

    def test_author_edit_version(self):
        self.assertTrue(can_access(self.alice, self.memory, Action.EDIT, NOW, expected_version=4))
        self.assertFalse(can_access(self.alice, self.memory, Action.EDIT, NOW, expected_version=3))
        self.assertFalse(can_access(self.alice, self.memory, Action.EDIT, NOW))

    def test_partner_cannot_edit_or_delete(self):
        for action in (Action.EDIT, Action.DELETE):
            self.assertFalse(can_access(self.bob, self.memory, action, NOW, expected_version=4))

    def test_deleted_hidden(self):
        deleted = Memory("pair1", "alice", 4, deleted=True)
        for action in Action:
            self.assertFalse(can_access(self.alice, deleted, action, NOW, expected_version=4))

    def test_upload_author_only(self):
        self.assertTrue(can_access(self.alice, self.memory, Action.UPLOAD, NOW))
        self.assertFalse(can_access(self.bob, self.memory, Action.UPLOAD, NOW))

    def test_photo_constraints(self):
        self.assertTrue(valid_photo("image/jpeg", MAX_PHOTO_BYTES))
        self.assertFalse(valid_photo("image/jpeg", MAX_PHOTO_BYTES + 1))
        self.assertFalse(valid_photo("image/jpeg", 0))
        self.assertFalse(valid_photo("image/svg+xml", 10))

    def test_text_constraints(self):
        self.assertTrue(valid_story("x" * MAX_STORY_CHARS))
        self.assertFalse(valid_story("x" * (MAX_STORY_CHARS + 1)))
        self.assertTrue(valid_message("x" * MAX_MESSAGE_CHARS))
        self.assertFalse(valid_message("x" * (MAX_MESSAGE_CHARS + 1)))
        self.assertFalse(valid_message("   "))


if __name__ == "__main__":
    unittest.main()
