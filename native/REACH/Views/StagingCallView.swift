import SwiftUI

struct StagingCallView: View {
    let stopID: UUID
    var availability: ReachHomeAvailability = .checking
    var now = Date()
    var pairingBusy = false
    @StateObject private var call = StagingCallController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var muted = false
    @State private var cameraEnabled = true

    var body: some View {
        ReachGlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                Label("Reach for each other", systemImage: "hands.sparkles")
                    .font(.title3.weight(.semibold))
                Text(call.peer == nil ? availability.title(at: now) : call.status)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("reach.connectionStatus")
                if let peer = call.peer {
                    StagingVideoPanel(peer: peer)
                    Toggle("Mute microphone", isOn: $muted).onChange(of: muted) { _, value in peer.setMuted(value) }
                    Toggle("Camera enabled", isOn: $cameraEnabled).onChange(of: cameraEnabled) { _, value in peer.setCameraEnabled(value) }
                    Button("End live call", role: .destructive) { Task { await call.end() } }
                        .buttonStyle(.borderedProminent).tint(.pink)
                        .frame(minHeight: 48)
                } else {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { handActions }
                    } else {
                        HStack(alignment: .top, spacing: 12) { handActions }
                    }
                    if call.status != "No live staging call." {
                        Text(call.status).font(.footnote).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text("A hand is an invitation. Camera and microphone start only when you choose to open or take a hand.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.85))
                DisclosureGroup("About this staging connection") {
                    Text("Both partners must explicitly join. Keep REACH in the foreground. Direct/STUN connectivity may not work on every network; a TURN relay is not configured.")
                        .font(.footnote).padding(.top, 8)
                }.font(.footnote)
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

    @ViewBuilder private var handActions: some View {
        handButton("My hand is open", subtitle: "I’m ready to connect", symbol: "hand.raised.fill", color: .pink,
                   enabled: availability.canOpen(at: now), join: false)
        handButton("Take their hand", subtitle: availability.canTake(at: now) ? "Connect to your partner" : "Waiting for their hand",
                   symbol: "hand.draw.fill", color: .indigo, enabled: availability.canTake(at: now), join: true)
    }
    private func handButton(_ title: String, subtitle: String, symbol: String, color: Color, enabled: Bool, join: Bool) -> some View {
        Button {
            muted = false; cameraEnabled = true
            Task { await call.start(join: join) }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.headline).multilineTextAlignment(.center)
                Text(subtitle).font(.caption).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10).padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 136)
            .background(LinearGradient(colors: [color.opacity(0.9), .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(.white.opacity(0.28)))
            .opacity(enabled && !call.busy && !pairingBusy ? 1 : 0.52)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || call.busy || pairingBusy)
        .accessibilityHint(join ? "Explicitly joins an authorized, unexpired open hand and requests camera and microphone permission." : "Creates a new authorized invitation and requests camera and microphone permission.")
        .accessibilityIdentifier(join ? "reach.takeHand" : "reach.openHand")
    }
}

private struct StagingVideoPanel: View {
    @ObservedObject var peer: NativeWebRTCPeer
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Partner video").font(.caption)
            WebRTCVideoView(track: peer.remoteVideo).frame(height: 240).background(.black).clipShape(RoundedRectangle(cornerRadius: 18))
            Text("Your camera").font(.caption)
            WebRTCVideoView(track: peer.localVideo).frame(height: 120).background(.black).clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
