import SwiftUI

struct StagingCallView: View {
    @ObservedObject var call: StagingCallController
    let stopID: UUID
    let availability: ReachHomeAvailability
    let roomID: String?
    let now: Date
    let pairingBusy: Bool
    let withdrawOwnRoom: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var muted = false
    @State private var cameraEnabled = true
    @State private var showsCall = false

    private var controls: ReachHandControls {
        ReachHandControls(availability: availability, now: now, phase: call.phase,
                          roomID: roomID, busy: call.busy || pairingBusy)
    }

    var body: some View {
        VStack(spacing: 14) {
            if let title = call.phase.title, call.phase != .outgoing {
                statusLabel(title)
            } else if call.phase == .idle && !availability.paired(at: now) {
                statusLabel(availability.title(at: now))
            }

            if call.phase.showsHandCards {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 12) { handActions }
                } else {
                    HStack(spacing: 12) { handActions }
                }
            } else if call.phase.hasStarted {
                Button(call.phase.showsFullScreenCall ? "End Call" : "Cancel Connection", role: .destructive) {
                    Task { await call.end() }
                }
                .buttonStyle(.borderedProminent).tint(.pink)
                .frame(minHeight: 48)
                .accessibilityIdentifier("reach.endCall")

            }

            if let peer = call.peer, call.phase.hasStarted {
                ReachGlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Mute microphone", isOn: $muted).onChange(of: muted) { _, value in peer.setMuted(value) }
                        Toggle("Send video", isOn: $cameraEnabled).onChange(of: cameraEnabled) { _, value in peer.setCameraEnabled(value) }
                    }
                }
            }
        }
        .onChange(of: call.phase, initial: true) { _, phase in
            showsCall = phase.showsFullScreenCall && call.peer != nil
        }
        .fullScreenCover(isPresented: $showsCall) {
            if let peer = call.peer {
                ActiveVideoCallView(call: call, peer: peer, muted: $muted, cameraEnabled: $cameraEnabled)
                    .interactiveDismissDisabled()
            }
        }
        .onChange(of: stopID) { _, _ in
            // Stop local capture even if server-side revocation is delayed/offline.
            Task { await call.end() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await call.end() } }
        }
        .onDisappear { Task { await call.end() } }
    }

    private func statusLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            if [.preparing, .connecting, .ending].contains(call.phase) {
                ProgressView().accessibilityHidden(true)
            } else if call.phase == .connected {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
            }
            Text(title).multilineTextAlignment(.center)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("reach.connectionStatus")
    }

    @ViewBuilder private var handActions: some View {
        if controls.showsOutgoing {
            handButton("Withdraw my hand", subtitle: "Your hand is open", symbol: "hand.raised.fill",
                       tint: .pink, enabled: controls.canWithdraw, id: "reach.withdrawHand") {
                if call.phase == .outgoing {
                    Task { await call.end() }
                } else if let roomID {
                    withdrawOwnRoom(roomID)
                }
            }
        } else {
            handButton("Open my hand", subtitle: controls.canOpen ? "Invite your partner" : "Unavailable",
                       symbol: "hand.raised.fill", tint: .pink, enabled: controls.canOpen, id: "reach.openHand",
                       hint: "Opens an invitation and uses your camera and microphone with permission.") {
                start()
            }
        }
        handButton("Take their hand", subtitle: takeSubtitle,
                   symbol: "hand.draw.fill", tint: .purple, enabled: controls.canTake, id: "reach.takeHand",
                   incoming: controls.canTake, hint: "Accepts the invitation and uses your camera and microphone with permission.") {
            guard let roomID else { return }
            start(joining: roomID)
        }
    }

    private var takeSubtitle: String {
        if controls.canTake { return "Their hand is open" }
        return availability.paired(at: now) ? "Waiting for their hand" : "Unavailable"
    }

    private func start(joining roomID: String? = nil) {
        muted = false
        cameraEnabled = true
        Task { await call.start(joining: roomID) }
    }

    private func handButton(_ title: String, subtitle: String, symbol: String, tint: Color,
                            enabled: Bool, id: String, incoming: Bool = false, hint: String = "",
                            action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 23)
        return Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(enabled ? .white : .white.opacity(0.68))
                    .symbolEffect(.pulse, options: .repeating, isActive: incoming && !reduceMotion && scenePhase == .active)
                    .accessibilityHidden(true)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.88))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 126)
            .background {
                shape.fill(.black.opacity(reduceTransparency ? 1 : 0.63))
                shape.fill(LinearGradient(colors: [tint.opacity(enabled ? 0.52 : 0.23), .indigo.opacity(0.22)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(shape.strokeBorder(tint.opacity(incoming ? 0.95 : 0.48), lineWidth: incoming ? 2 : 1))
            .shadow(color: incoming ? .pink.opacity(0.55) : .black.opacity(0.24), radius: incoming ? 13 : 6, y: 3)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .accessibilityHint(enabled ? hint : "")
        .accessibilityIdentifier(id)
    }
}
