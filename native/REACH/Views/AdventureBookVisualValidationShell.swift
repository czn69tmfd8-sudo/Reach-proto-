#if DEBUG
import SwiftUI

/// Offline visual fixture selected only by an explicit debug launch argument.
/// No coordinator, identity, network or photo-library dependencies are created.
struct AdventureBookVisualValidationShell: View {
    let page: Int
    @State private var selected = 2
    var body: some View {
        TabView(selection: $selected) {
            Text("Offline visual fixture").tabItem { Label("Reach", systemImage: "heart.fill") }.tag(0)
            Text("Offline visual fixture").tabItem { Label("Together", systemImage: "sparkles") }.tag(1)
            NavigationStack { ReachAdventureBookPreview(initialPage: page) }
                .tabItem { Label("Us", systemImage: "person.2.fill") }.tag(2)
        }
        .tint(.pink)
        .toolbarBackground(Color(red: 0.12, green: 0.07, blue: 0.19), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
#endif
