import SwiftUI

@main
struct REACHApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var reachCoordinator = ReachCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(reachCoordinator)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .reach
}

enum AppTab: Hashable {
    case reach, together, us
}
