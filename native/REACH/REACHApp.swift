import SwiftUI

@main
struct REACHApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .reach
    @Published var connection = ConnectionState()
}

enum AppTab: Hashable {
    case reach, together, us
}
