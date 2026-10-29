import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ReachHomeView()
                .tabItem { Label("Reach", systemImage: "heart.fill") }
                .tag(AppTab.reach)

            PlaceholderView(title: "Together", subtitle: "Shared experiences will migrate here after validation.")
                .tabItem { Label("Together", systemImage: "person.2.fill") }
                .tag(AppTab.together)

            PlaceholderView(title: "Us", subtitle: "Your shared relationship space.")
                .tabItem { Label("Us", systemImage: "sparkles") }
                .tag(AppTab.us)
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding()
    }
}
