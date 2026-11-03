import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ReachHomeView()
                .tabItem { Label("Reach", systemImage: "heart.fill") }
                .tag(AppTab.reach)

            StagingConnectionView()
                .tabItem { Label("Staging", systemImage: "network") }
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

private struct StagingConnectionView: View {
    @State private var result = "Check staging sign-in and pairing on this device."
    @State private var checking = false

    var body: some View {
        VStack(spacing: 16) {
            Text("REACH Test Zone").font(.largeTitle.bold())
            Text(result).multilineTextAlignment(.center)
            Button("Check staging connection") {
                checking = true
                result = "Checking staging…"
            }
            .buttonStyle(.borderedProminent)
            .disabled(checking)
        }
        .padding()
        .task(id: checking) {
            guard checking else { return }
            result = await Self.checkStaging()
            checking = false
        }
    }

    private nonisolated static func checkStaging() async -> String {
        do {
            let dependencies = try FirebaseDependencyFactory.staging()
            let resolver = PairResolver(auth: dependencies.auth, pairs: dependencies.pairs)
            switch try await resolver.resolveCurrentPartnership() {
            case .authorized:
                return "Staging sign-in and pairing verified. Audio and video are unavailable in this check."
            case .noMemberLock:
                return "Signed in to staging. This installation has no staging pairing."
            case .pairMissing:
                return "The staging pairing record could not be found."
            case .pairRevoked:
                return "The staging pairing has been revoked."
            case .pairIncomplete:
                return "The staging pairing is waiting for a partner."
            case .memberMismatch:
                return "This installation is not authorized for the staging pairing."
            }
        } catch {
            return error.localizedDescription
        }
    }
}
