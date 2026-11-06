import SwiftUI

@main
struct REACHApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var reachCoordinator = ReachCoordinator()

    var body: some Scene {
        WindowGroup {
            if NSClassFromString("XCTestCase") != nil {
                // Hosted unit tests must not start the interactive UI's live
                // staging sign-in or listeners as an incidental launch effect.
                Color.clear
            } else {
                RootView()
                    .environmentObject(appState)
                    .environmentObject(reachCoordinator)
            }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .reach
    // In-memory presentation preference only. Photo selection/storage can be added
    // later without coupling it to identity, consent, or the native pairing lock.
    @Published var homeBackground: ReachHomeBackgroundSource = .originalSunset
}

enum AppTab: Hashable {
    case reach, together, us
}
