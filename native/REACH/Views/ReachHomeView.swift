import SwiftUI

struct ReachHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.95), .purple.opacity(0.75), .pink.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()
                    Text("REACH")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                    Text("Reach for each other, same moment, any distance.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.82))

                    connectionCard
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 14) {
            Text(statusText).font(.headline)

            HStack(spacing: 12) {
                action(title: "Take their hand", icon: "hand.raised.fill")
                action(title: "My hand is open", icon: "heart.fill")
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private var statusText: String {
        guard let session = appState.connection.session else { return "Ready for each other" }
        switch session.phase {
        case .open: return session.openedBy == appState.connection.partnership?.localMemberID ? "Your hand is open" : "Your partner’s hand is open"
        case .connecting: return "Connecting…"
        case .live: return "Connected"
        case .recovering: return "Reconnecting…"
        case .ended: return "Reach ended"
        case .failed: return "Connection needs attention"
        }
    }

    private func action(title: String, icon: String) -> some View {
        Button(action: {}) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.title)
                Text(title).font(.headline).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple.opacity(0.8))
    }
}
