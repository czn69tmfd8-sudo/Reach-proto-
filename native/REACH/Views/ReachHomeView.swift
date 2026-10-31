import SwiftUI

struct ReachHomeView: View {
    @EnvironmentObject private var reach: ReachCoordinator

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
            .task { await reach.bootstrap() }
            .alert("REACH", isPresented: Binding(
                get: { reach.errorMessage != nil },
                set: { if !$0 { reach.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { reach.errorMessage = nil }
            } message: {
                Text(reach.errorMessage ?? "")
            }
        }
    }

    private var connectionCard: some View {
        VStack(spacing: 14) {
            Text(statusText).font(.headline)

            if let session = reach.state.session {
                if session.openedBy == reach.state.partnership?.localMemberID {
                    Text("Leave REACH open. Your partner can take your hand when they're ready.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.75))
                } else if session.phase == .open {
                    action(title: "Take their hand", icon: "hand.raised.fill") {
                        Task { await reach.takeHand() }
                    }
                }

                Button("End REACH", role: .destructive) {
                    Task { await reach.endReach() }
                }
                .buttonStyle(.bordered)
            } else {
                action(title: "My hand is open", icon: "heart.fill") {
                    Task { await reach.openHand() }
                }
                .disabled(!reach.state.canOpenHand)

                #if DEBUG
                Button("Simulate partner opening their hand") {
                    Task { await reach.simulatePartnerOpeningHand() }
                }
                .font(.caption)
                #endif
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private var statusText: String {
        guard let session = reach.state.session else {
            switch reach.state.mediaPermission {
            case .requesting: return "Preparing camera and microphone…"
            case .denied: return "Camera and microphone access needed"
            default: return "Ready for each other"
            }
        }

        switch session.phase {
        case .open:
            return session.openedBy == reach.state.partnership?.localMemberID
                ? "Your hand is open"
                : "\(reach.state.partnership?.partnerDisplayName ?? "Your partner")’s hand is open"
        case .connecting: return "Connecting…"
        case .live: return "Connected"
        case .recovering: return "Reconnecting…"
        case .ended: return "Reach ended"
        case .failed: return "Connection needs attention"
        }
    }

    private func action(title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
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
