import AVFoundation
import Combine
import SwiftUI
import UIKit

struct ActiveVideoCallView: View {
    @ObservedObject var call: StagingCallController
    @ObservedObject var peer: NativeWebRTCPeer
    @Binding var muted: Bool
    @Binding var cameraEnabled: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var previousIdleTimerState: Bool?
    @State private var audioOutput = CallAudioOutput.current

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let remoteVideo = peer.remoteVideo {
                WebRTCVideoView(track: remoteVideo)
                    .ignoresSafeArea()
                    .accessibilityLabel("Partner video")
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(call.phase == .interrupted ? "Reconnecting…" : "Video call")
                        .font(.headline)
                        .accessibilityIdentifier("reach.connectionStatus")
                    Text(audioOutput.title)
                        .font(.subheadline)
                        .accessibilityIdentifier("reach.callAudioOutput")
                }
                Spacer(minLength: 8)
                if cameraEnabled {
                    WebRTCVideoView(track: peer.localVideo)
                        .frame(width: 88, height: 118)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Your camera preview")
                }
            }
            .padding(12)
            .background(.black.opacity(0.78))
        }
        .safeAreaInset(edge: .bottom) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { callControls }
                VStack(spacing: 8) { callControls }
            }
            .buttonStyle(.borderedProminent)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.78))
        }
        .preferredColorScheme(.dark)
        .onChange(of: keepsScreenAwake, initial: true) { _, keepAwake in
            if keepAwake {
                previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                restoreIdleTimer()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await call.end() } }
            if phase == .active { audioOutput = .current }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { _ in
            audioOutput = .current
        }
        .onDisappear { restoreIdleTimer() }
    }

    private var keepsScreenAwake: Bool {
        scenePhase == .active && call.phase.showsFullScreenCall
    }

    private func restoreIdleTimer() {
        guard let previousIdleTimerState else { return }
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
        self.previousIdleTimerState = nil
    }

    @ViewBuilder private var callControls: some View {
        Button {
            muted.toggle()
            peer.setMuted(muted)
        } label: {
            Label(muted ? "Unmute" : "Mute", systemImage: muted ? "mic.slash.fill" : "mic.fill")
                .frame(minHeight: 32)
        }
        .tint(.gray)
        .accessibilityIdentifier("reach.callMute")
        Button {
            cameraEnabled.toggle()
            peer.setCameraEnabled(cameraEnabled)
        } label: {
            Label(cameraEnabled ? "Stop video" : "Send video", systemImage: cameraEnabled ? "video.fill" : "video.slash.fill")
                .frame(minHeight: 32)
        }
        .tint(.gray)
        .accessibilityIdentifier("reach.callVideo")
        Button(role: .destructive) {
            Task { await call.end() }
        } label: {
            Label("End call", systemImage: "phone.down.fill").frame(minHeight: 32)
        }
        .tint(.red)
        .accessibilityIdentifier("reach.endCall")
    }
}
