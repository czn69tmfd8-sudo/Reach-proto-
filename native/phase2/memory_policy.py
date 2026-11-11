"""Pure, Firebase-free Phase 2 memory authorization model.

Not imported by the shipping REACH application. All server-side rules must enforce
the same decisions independently; this module is not a security boundary.
"""
from dataclasses import dataclass
from enum import Enum

MAX_STORY_CHARS = 12000
MAX_MESSAGE_CHARS = 4000
MAX_PHOTO_BYTES = 10 * 1024 * 1024
ALLOWED_PHOTO_MIME = frozenset({"image/jpeg", "image/png", "image/heic"})


class Action(str, Enum):
    READ = "read"
    CREATE = "create"
    EDIT = "edit"
    DELETE = "delete"
    UPLOAD = "upload"


@dataclass(frozen=True)
class Membership:
    user_id: str
    pair_id: str
    active: bool
    revoked: bool = False
    expires_at: int = 0

    def valid_for(self, pair_id: str, now: int) -> bool:
        return (bool(self.user_id) and self.pair_id == pair_id and self.active
                and not self.revoked and self.expires_at > now)


@dataclass(frozen=True)
class Memory:
    pair_id: str
    author_id: str
    version: int
    deleted: bool = False


def can_access(member: Membership | None, memory: Memory, action: Action,
               now: int, *, expected_version: int | None = None) -> bool:
    if member is None or not member.valid_for(memory.pair_id, now):
        return False
    if memory.deleted:
        return False
    if action == Action.READ:
        return True
    if action in (Action.EDIT, Action.DELETE):
        return (member.user_id == memory.author_id and expected_version is not None
                and expected_version == memory.version)
    if action in (Action.CREATE, Action.UPLOAD):
        return member.user_id == memory.author_id
    return False


def valid_photo(mime: str, size_bytes: int) -> bool:
    return mime in ALLOWED_PHOTO_MIME and 0 < size_bytes <= MAX_PHOTO_BYTES


def valid_story(text: str) -> bool:
    return isinstance(text, str) and len(text) <= MAX_STORY_CHARS


def valid_message(text: str) -> bool:
    return isinstance(text, str) and 0 < len(text.strip()) <= MAX_MESSAGE_CHARS
