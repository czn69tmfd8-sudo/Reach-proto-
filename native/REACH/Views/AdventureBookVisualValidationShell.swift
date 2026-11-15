#if DEBUG
import SwiftUI

/// Offline visual fixture selected only by an explicit debug launch argument.
/// No coordinator, identity, network or photo-library dependencies are created.
struct AdventureBookVisualValidationShell: View {
    let page: Int
    var useLiveGallery = false
    @State private var selected = 2
    var body: some View {
        TabView(selection: $selected) {
            Text("Offline visual fixture").tabItem { Label("Reach", systemImage: "heart.fill") }.tag(0)
            Text("Offline visual fixture").tabItem { Label("Together", systemImage: "sparkles") }.tag(1)
            NavigationStack {
                if useLiveGallery {
                    ReachAdventureBookLive(visualBook: galleryFixture, page: page)
                } else {
                    ReachAdventureBookPreview(initialPage: page)
                }
            }
                .tabItem { Label("Us", systemImage: "person.2.fill") }.tag(2)
        }
        .tint(.pink)
        .toolbarBackground(Color(red: 0.12, green: 0.07, blue: 0.19), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }

    private var galleryFixture: AdventureBook {
        let code = "ABCDEFGHJKLM"
        let titles = ["Cabin Weekend", "Our First Hike", "Lake Weekend", "Campfire Nights",
                      "City Escape", "Mountain Drive", "A Little Detour", "Forest Walk", "The Next Chapter"]
        let memories = titles.enumerated().map { index, title in
            AdventureMemory(id: "fixture-\(index)", pairCode: code, creatorUID: "fixture",
                            title: title, occurredAt: Date(timeIntervalSince1970: 1_740_000_000 + Double(8 - index) * 86400),
                            stories: [], photos: [], comments: [], pageOrder: index)
        }
        return AdventureBook(pairCode: code, memories: memories)
    }
}
#endif
