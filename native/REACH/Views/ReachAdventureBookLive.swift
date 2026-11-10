import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// Staging-only live Adventure Book surface. The existing preview remains
/// available and no data is copied from the user's private scrapbook.
struct ReachAdventureBookLive: View {
    @State private var book: AdventureBook?
    @State private var pairCode: String?
    @State private var error: String?
    @State private var busy = false
    @State private var showingNewMemory = false
    @State private var selectedMemory: AdventureMemory?
    @State private var commentDraft = ""
    @State private var page = 0
    @State private var repository = FirestoreAdventureBookRepository()

    var body: some View {
        ReachPage {
            Text("Our Adventure Book")
                .font(.system(.largeTitle, design: .serif).bold())
            Text("Two hearts. Two stories. One adventure.")
                .font(.subheadline).italic()
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
                Button("Try again") { Task { await connect() } }
                    .buttonStyle(.bordered)
            }
            if let book {
                let ordered = book.orderedMemories
                TabView(selection: $page) {
                    cover.tag(0)
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, memory in
                        memoryPage(memory).tag(index + 1)
                    }
                    addPage.tag(ordered.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 520)
                HStack {
                    Button("Previous") { page = max(0, page - 1) }.disabled(page == 0)
                    Spacer()
                    Text("Page \(page + 1) of \(ordered.count + 2)").font(.caption)
                    Spacer()
                    Button("Next") { page = min(ordered.count + 1, page + 1) }
                        .disabled(page == ordered.count + 1)
                }.buttonStyle(.bordered)
            } else if error == nil {
                ProgressView("Checking private pairing and loading our book…")
            }
        }
        .task { await connect() }
        .onDisappear { repository.stopObserving() }
        .sheet(isPresented: $showingNewMemory) {
            AdventureMemoryDraftEditor { title, date, story in
                Task { await create(title: title, date: date, story: story) }
            }
        }
        .sheet(item: $selectedMemory) { memory in
            AdventureStoryEditor(initialText: memory.stories.first(where: {
                $0.authorUID == Auth.auth().currentUser?.uid
            })?.text ?? "") { text in
                Task { await saveStory(memoryID: memory.id, text: text) }
            }
        }
    }

    private var cover: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "book.closed.fill").font(.system(size: 72))
            Text("Our Adventure\nBook")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            Image(systemName: "heart.fill").foregroundStyle(.pink)
            Text("The story we're writing together")
                .font(.system(.subheadline, design: .serif)).italic()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.orange)
        .background(Color(red: 0.32, green: 0.16, blue: 0.12),
                    in: RoundedRectangle(cornerRadius: 20))
        .padding(5)
    }

    private func memoryPage(_ memory: AdventureMemory) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(memory.title).font(.system(.title2, design: .serif).bold())
                Text(memory.occurredAt, style: .date).font(.caption)
                ForEach(memory.photos) { photo in
                    Label(photo.caption.isEmpty ? "Private photograph" : photo.caption,
                          systemImage: "photo")
                        .font(.caption)
                }
                ForEach(memory.stories, id: \.authorUID) { story in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(story.authorUID == Auth.auth().currentUser?.uid ? "My story" : "Partner's story")
                            .font(.caption.weight(.bold))
                        Text(story.text).font(.system(.subheadline, design: .serif)).italic()
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
                }
                Button("Write or edit my story") { selectedMemory = memory }
                    .buttonStyle(.bordered)
                Divider()
                Text("Our conversation").font(.headline)
                ForEach(memory.comments) { comment in
                    Text(comment.text).font(.subheadline)
                }
                TextField("Leave a comment", text: $commentDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Post comment") {
                    let text = commentDraft
                    commentDraft = ""
                    Task { await postComment(memoryID: memory.id, text: text) }
                }
                .disabled(busy || commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color(red: 0.29, green: 0.16, blue: 0.13))
        .background(Color(red: 0.96, green: 0.89, blue: 0.75),
                    in: RoundedRectangle(cornerRadius: 12))
        .padding(5)
    }

    private var addPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.text.square").font(.system(size: 52))
            Text("Our next adventure").font(.system(.title, design: .serif).bold())
            Button("Add a memory") { showingNewMemory = true }
                .buttonStyle(.borderedProminent).disabled(busy)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color(red: 0.29, green: 0.16, blue: 0.13))
        .background(Color(red: 0.96, green: 0.89, blue: 0.75),
                    in: RoundedRectangle(cornerRadius: 12))
        .padding(5)
    }

    private func connect() async {
        do {
            try FirebaseBootstrap.configureStaging()
            guard let uid = Auth.auth().currentUser?.uid else {
                throw AdventureBookRepositoryError.unauthorized
            }
            let lock = try await Firestore.firestore()
                .document("nativeStaging/v1/memberLocks/\(uid)").getDocument(source: .server)
            guard let code = lock.data()?["pairCode"] as? String else {
                throw AdventureBookRepositoryError.notPaired
            }
            pairCode = code
            let loaded = try await repository.load(pairCode: code)
            book = loaded
            error = nil
            try await repository.observe(pairCode: code) { result in
                switch result {
                case .success(let updated): book = updated
                case .failure(let failure):
                    book = nil
                    error = failure.localizedDescription
                }
            }
        } catch {
            book = nil
            self.error = error.localizedDescription
        }
    }

    private func create(title: String, date: Date, story: String) async {
        guard let code = pairCode, let uid = Auth.auth().currentUser?.uid else { return }
        busy = true
        defer { busy = false }
        do {
            let id = UUID().uuidString.lowercased()
            let memory = AdventureMemory(id: id, pairCode: code, creatorUID: uid,
                                         title: title, occurredAt: date, stories: [],
                                         photos: [], comments: [], pageOrder: book?.memories.count ?? 0)
            try await repository.createMemory(memory)
            if !story.isEmpty {
                try await repository.saveOwnStory(pairCode: code, memoryID: id,
                                                  text: story, expectedVersion: nil)
            }
            book = try await repository.load(pairCode: code)
        } catch { self.error = error.localizedDescription }
    }

    private func saveStory(memoryID: String, text: String) async {
        guard let code = pairCode, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            // Version must correspond to the editor's original server snapshot.
            // Until the editor carries that token, existing-story edits are
            // blocked instead of silently overwriting a newer contribution.
            let transport = FirestoreAdventureStoryTransport()
            let existing = try await transport.loadOwnStory(pairCode: code, memoryID: memoryID, uid: uid)
            guard existing == nil else { throw AdventureBookRepositoryError.conflict }
            try await repository.saveOwnStory(pairCode: code, memoryID: memoryID,
                                              text: text, expectedVersion: nil)
        } catch { self.error = error.localizedDescription }
    }

    private func postComment(memoryID: String, text: String) async {
        guard let code = pairCode else { return }
        do { try await repository.postComment(pairCode: code, memoryID: memoryID, text: text) }
        catch { error = error.localizedDescription }
    }
}
