import SwiftUI

/// Visual-only prototype. Sample content is not shared or persisted.
struct ReachAdventureBookPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    private let sample = AdventureMemory(
        id: "sample-memory", pairCode: "ABCDEFGHJKLM", creatorUID: "sample-one",
        title: "Our Lake Weekend", occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
        stories: [
            .init(authorUID: "sample-one", text: "What I remember most about that day…", updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            .init(authorUID: "sample-two", text: "My favourite part of our adventure…", updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        ], photos: [], comments: [], pageOrder: 0
    )
    private let paper = Color(red: 0.96, green: 0.89, blue: 0.75)
    private let ink = Color(red: 0.29, green: 0.16, blue: 0.13)

    var body: some View {
        ReachPage {
            Text("Our Adventure Book")
                .font(.system(.largeTitle, design: .serif).bold())
            Text("Two hearts. Two stories. One adventure.")
                .font(.subheadline).italic()
            Text("DESIGN PREVIEW · SAMPLE PAGES")
                .font(.caption2.weight(.bold))
            TabView(selection: $page) {
                cover.tag(0)
                memory.tag(1)
                nextPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 520)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
            HStack {
                Button("Previous") { if page > 0 { page -= 1 } }
                    .disabled(page == 0)
                Spacer()
                Text("Page \(page + 1) of 3")
                Spacer()
                Button("Next") { if page < 2 { page += 1 } }
                    .disabled(page == 2)
            }
            .buttonStyle(.bordered)
            Text("Swipe to turn pages. Real photos, synchronization and page-curl effects come later.")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var cover: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "book.closed.fill").font(.system(size: 72))
            Text("Our Adventure\nBook")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            Image(systemName: "heart.fill").foregroundStyle(.pink)
            Text("The story we're writing together")
                .font(.system(.subheadline, design: .serif)).italic()
            Spacer()
            Text("Swipe to open")
                .font(.caption)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.orange.opacity(0.9))
        .background(Color(red: 0.32, green: 0.16, blue: 0.12), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.brown, lineWidth: 4))
        .padding(5)
    }

    private var memory: some View {
        VStack(spacing: 14) {
            Text(sample.title)
                .font(.system(.title2, design: .serif).bold())
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .background(.brown.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("Photo placeholder")
            Text("One memory, two perspectives")
                .font(.caption).italic()
            HStack(alignment: .top, spacing: 10) {
                story("Partner's story", sample.stories[0].text)
                story("My story", sample.stories[1].text)
            }
            Divider()
            Label("Our conversation", systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline.weight(.semibold))
            Text("Shared comments will appear here.")
                .font(.caption)
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ink)
        .background(paper, in: RoundedRectangle(cornerRadius: 12))
        .padding(5)
    }

    private func story(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading).font(.caption.weight(.bold))
            Text(body).font(.system(.subheadline, design: .serif)).italic()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
    }

    private var nextPage: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "heart.text.square").font(.system(size: 50))
            Text("Our next adventure")
                .font(.system(.title, design: .serif).bold())
            Text("Every memory deserves a page in our story.")
                .multilineTextAlignment(.center)
            Text("New memory creation is not yet enabled.")
                .font(.caption)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(ink)
        .background(paper, in: RoundedRectangle(cornerRadius: 12))
        .padding(5)
    }
}
