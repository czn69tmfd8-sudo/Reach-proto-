import Foundation
@main struct Checks {
 static func main() throws {
  let now = Date(timeIntervalSince1970: 1000)
  let alice = PairMembership(userID: "alice", pairID: "p1", active: true, expiresAt: Date(timeIntervalSince1970: 2000))
  let bob = PairMembership(userID: "bob", pairID: "p1", active: true, expiresAt: Date(timeIntervalSince1970: 2000))
  let outsider = PairMembership(userID: "outsider", pairID: "p2", active: true, expiresAt: Date(timeIntervalSince1970: 2000))
  let revoked = PairMembership(userID: "alice", pairID: "p1", active: true, revoked: true, expiresAt: Date(timeIntervalSince1970: 2000))
  let memory = try SharedMemory(id: "m1", pairID: "p1", authorID: "alice", version: 4)
  var passed = 0
  func check(_ ok: Bool, _ reason: String) { precondition(ok, reason); passed += 1 }
  check(memory.canRead(bob, at: now), "partner read")
  check(!memory.canRead(outsider, at: now), "outsider")
  check(!memory.canRead(revoked, at: now), "revoked")
  check(memory.canEdit(alice, expectedVersion: 4, at: now), "author edit")
  check(!memory.canEdit(bob, expectedVersion: 4, at: now), "partner edit")
  check(!memory.canEdit(alice, expectedVersion: 3, at: now), "stale edit")
  let story = try PartnerStory(authorID: "bob", text: "My memory", version: 2)
  check(story.canEdit(bob, memory: memory, expectedVersion: 2, at: now), "story author")
  check(!story.canEdit(alice, memory: memory, expectedVersion: 2, at: now), "story impersonation")
  let entry = try ConversationEntry(id: "e1", authorID: "bob", text: "Hi")
  check(entry.canAppend(bob, memory: memory, at: now), "conversation author")
  check(!entry.canAppend(alice, memory: memory, at: now), "conversation impersonation")
  let photo = try PhotoUploadIntent(memoryID: "m1", uploaderID: "alice", mime: "image/jpeg", bytes: 100)
  check(photo.canStage(alice, memory: memory, at: now), "photo author")
  check(!photo.canStage(bob, memory: memory, at: now), "photo impersonation")
  check(decideOfflineEdit(member: alice, memory: memory, expectedVersion: 4, now: now) == .apply, "offline apply")
  check(decideOfflineEdit(member: alice, memory: memory, expectedVersion: 3, now: now) == .conflict, "offline conflict")
  check(decideOfflineEdit(member: revoked, memory: memory, expectedVersion: 4, now: now) == .reject, "offline revoked")
  print("PASS: \(passed) Swift Phase 2 checks")
 }
}
