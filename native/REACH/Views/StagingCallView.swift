import SwiftUI

struct StagingCallView: View {
    let stopID: UUID
    @StateObject private var call = StagingCallController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var muted = false
    @State private var cameraEnabled = true

    var body: some View {
        Section("Live staging call") {
            Text(call.status)
            if let peer = call.peer {
                StagingVideoPanel(peer: peer)
                Toggle("Mute microphone", isOn: $muted).onChange(of: muted) { _, value in peer.setMuted(value) }
                Toggle("Camera enabled", isOn: $cameraEnabled).onChange(of: cameraEnabled) { _, value in peer.setCameraEnabled(value) }
                Button("End live call", role: .destructive) { Task { await call.end() } }
            } else {
                Button("Open hand with camera and microphone") {
                    muted = false; cameraEnabled = true
                    Task { await call.start(join: false) }
                }.disabled(call.busy)
                Button("Take partner’s open hand") {
                    muted = false; cameraEnabled = true
                    Task { await call.start(join: true) }
                }.disabled(call.busy)
            }
            Text("Both partners must explicitly join. Keep REACH in the foreground. This prototype uses direct/STUN connectivity; some networks require a TURN relay that is not configured yet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: stopID) { _, _ in
            // Stop this installation's capture immediately, even if server-side
            // revocation is delayed or rejected while the device is offline.
            Task { await call.end() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await call.end() } }
        }
        .onDisappear { Task { await call.end() } }
    }
}

private struct StagingVideoPanel: View {
    @ObservedObject var peer: NativeWebRTCPeer
    var body: some View {
        VStack {
            Text("Partner video")
            WebRTCVideoView(track: peer.remoteVideo).frame(height: 240).background(.black)
            Text("Your camera")
            WebRTCVideoView(track: peer.localVideo).frame(height: 120).background(.black)
        }
    }
}
