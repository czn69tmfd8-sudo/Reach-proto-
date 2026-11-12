import SwiftUI

/// Explicit sample book. Drafts exist only in view state and never reach Firebase.
struct ReachAdventureBookPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.dismiss) private var dismiss
    @State private var page: Int
    @State private var selected: Int?
    @State private var personalStory = "I remember how easy it felt to be with you there. No rush, no distractions—just us, good conversation, and a reminder of how lucky I am. ♡"
    @State private var showingStoryEditor = false
    @State private var showingMemoryEditor = false
    @State private var drafts: [(title: String, date: Date, story: String)] = []
    private let titles = ["The Lake Weekend", "Campfire Nights", "Our City Escape", "The Mountain Drive", "A Little Detour", "The Next Chapter"]
    private let dates = ["May 17, 2025", "June 7, 2025", "July 12, 2025", "August 23, 2025", "September 6, 2025", "October 11, 2025"]

    private var sampleCount: Int { titles.count + drafts.count }
    private var spreadCount: Int { AdventureGalleryPagination.spreadCount(memoryCount: sampleCount) }

    init(initialPage: Int = 0) {
        _page = State(initialValue: max(0, initialPage == 2 ? 1 : initialPage))
    }

    var body: some View {
        VStack(spacing: 0) {
            AdventureBookHeader(title: selected.map { sampleTitle(at: $0) } ?? "Our Adventure Book") {
                if selected != nil { selected = nil }
                else if page == 0 { dismiss() }
                else { turn(to: page - 1) }
            }
            Text("SAMPLE BOOK · NOT SAVED OR SHARED")
                .font(.caption2.weight(.semibold)).tracking(1)
                .foregroundStyle(.white).padding(.bottom, 5)
            if let selected {
                memory(at: selected)
                Button {
                    self.selected = nil
                } label: {
                    Label("Back to memories", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(.white)
            } else {
                TabView(selection: $page) {
                    ScrollView {
                        AdventureLeatherCover { turn(to: 1) }
                            .frame(maxWidth: 440).padding(.top, 12)
                        Text("Decorative sample travel prints")
                            .font(.caption2).foregroundStyle(.white.opacity(0.85))
                    }.tag(0)
                    ForEach(0..<spreadCount, id: \.self) { spread in
                        gallery(spread: spread).tag(spread + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: page)
                .onChange(of: sampleCount) { _, count in
                    page = AdventureGalleryPagination.clampedPage(page, memoryCount: count)
                }
                HStack {
                    Button { turn(to: page - 1) } label: {
                        Label("Previous", systemImage: "chevron.left").frame(minHeight: 44)
                    }.disabled(page == 0)
                    Spacer()
                    Text(page == 0 ? "Cover" : "Memories · \(page) of \(spreadCount)")
                        .font(.caption)
                    Spacer()
                    Button { turn(to: page + 1) } label: {
                        Label("Next", systemImage: "chevron.right").frame(minHeight: 44)
                    }.disabled(page == spreadCount)
                }
                .font(.caption).foregroundStyle(.white).padding(.horizontal, 16)
            }
        }
        .background { ReachHomeBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $showingStoryEditor) {
            AdventureStoryEditor(initialText: personalStory) { personalStory = $0 }
        }
        .sheet(isPresented: $showingMemoryEditor) {
            AdventureMemoryDraftEditor { title, date, text in drafts.append((title, date, text)) }
        }
    }

    private func turn(to value: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) { page = AdventureGalleryPagination.clampedPage(value, memoryCount: sampleCount) }
    }

    private func sampleTitle(at index: Int) -> String {
        index < titles.count ? titles[index] : drafts[index - titles.count].title
    }

    private func gallery(spread: Int) -> some View {
        AdventureParchmentPage {
            VStack(spacing: 14) {
                AdventureGalleryHeading()
                Text("Page \(spread + 1) of \(spreadCount)")
                    .font(AdventureBookPalette.serif(14, relativeTo: .caption))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                          count: dynamicType.isAccessibilitySize ? 1 : 2), spacing: 16) {
                    ForEach(Array(AdventureGalleryPagination.memoryRange(spread: spread, memoryCount: sampleCount)), id: \.self) { index in
                        Button {
                            selected = index
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                if index < titles.count {
                                    AdventureMountedPhoto(sample: index, title: titles[index])
                                        .frame(height: dynamicType.isAccessibilitySize ? 250 : 155)
                                } else {
                                    AdventureMountedFrame(title: sampleTitle(at: index)) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(AdventureBookPalette.paper.opacity(0.45))
                                    }
                                    .frame(height: dynamicType.isAccessibilitySize ? 250 : 155)
                                }
                                HStack {
                                    if index < dates.count {
                                        Text(dates[index])
                                    } else {
                                        Text(drafts[index - titles.count].date, style: .date)
                                    }
                                    Spacer(minLength: 1)
                                    Image(systemName: "heart").foregroundStyle(AdventureBookPalette.burgundy)
                                }
                                .font(AdventureBookPalette.serif(13, relativeTo: .caption))
                                .padding(.horizontal, 6)
                            }
                            .foregroundStyle(AdventureBookPalette.ink)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open sample memory: \(sampleTitle(at: index))")
                    }
                }
                Button { showingMemoryEditor = true } label: {
                    Label("Add a Sample Memory", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(AdventureBookPalette.serif(18)).foregroundStyle(.white)
                .background(AdventureBookPalette.burgundy, in: Capsule())
                .padding(.horizontal, 24)
            }
        }
    }

    private func memory(at index: Int) -> some View {
        AdventureParchmentPage {
            VStack(spacing: 14) {
                AdventureMountedPhoto(sample: index, title: nil)
                    .frame(height: 205).rotationEffect(.degrees(-1.2))
                VStack(spacing: 3) {
                    Text(sampleTitle(at: index)).font(AdventureBookPalette.handwriting(28, relativeTo: .title2))
                        .multilineTextAlignment(.center)
                    Text(index < dates.count ? dates[index] : drafts[index - titles.count].date.formatted(date: .abbreviated, time: .omitted)).font(AdventureBookPalette.serif(15, relativeTo: .caption))
                    Label("Illustrated sample memory", systemImage: "mappin.and.ellipse")
                        .font(AdventureBookPalette.serif(13, relativeTo: .caption))
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 10) { stories }
                        .frame(minWidth: dynamicType.isAccessibilitySize ? 900 : 0)
                    VStack(spacing: 12) { stories }
                }
                Button("Write my sample story") { showingStoryEditor = true }
                    .font(AdventureBookPalette.serif(16)).frame(minHeight: 44)
                    .foregroundStyle(AdventureBookPalette.burgundy)
                Divider().overlay(AdventureBookPalette.ink.opacity(0.15))
                HStack {
                    Label("Our Conversation", systemImage: "bubble.left.and.bubble.right")
                        .font(AdventureBookPalette.script(22, relativeTo: .headline))
                    Spacer()
                    Text("Sample").font(.caption2)
                }
                conversation("Partner", "I’m still thinking about that weekend. ♡")
                conversation("You", "Me too. Let’s make it an annual tradition. ♡")
                Text("Illustrations and sample words only. Your saved memories are in the live book.")
                    .font(.caption).multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var stories: some View {
        AdventureStoryCard(heading: "Partner’s Story", text: "The moment I remember most was sitting beside you at the dock, watching the sun go down. It felt so peaceful and just right. ♡")
        AdventureStoryCard(heading: "My Story", text: personalStory, tint: .blue)
    }

    private func conversation(_ author: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(.brown.opacity(0.7))
            VStack(alignment: .leading, spacing: 3) {
                Text(author).font(AdventureBookPalette.serif(14, relativeTo: .caption).bold())
                Text(text).font(AdventureBookPalette.serif(16))
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "heart").foregroundStyle(AdventureBookPalette.burgundy)
        }
        .padding(8).background(.white.opacity(0.24))
    }
}
