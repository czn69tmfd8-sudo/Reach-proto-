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
                launchView
            }
        }
    }

    @ViewBuilder private var launchView: some View {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--adventure-sample-page=") }),
           let value = Int(argument.split(separator: "=").last ?? ""), (0...2).contains(value) {
            AdventureBookVisualValidationShell(page: value)
        } else {
            RootView().environmentObject(appState).environmentObject(reachCoordinator)
        }
        #else
        RootView().environmentObject(appState).environmentObject(reachCoordinator)
        #endif
    }

}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .reach
}

enum AppTab: Hashable {
    case reach, together, us
}
