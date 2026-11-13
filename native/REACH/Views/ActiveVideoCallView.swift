import AVFoundation
import Combine
import SwiftUI

struct ActiveVideoCallView: View {
    @ObservedObject var call: StagingCallController
    @ObservedObject var peer: NativeWebRTCPeer
    @Binding var muted: Bool
    @Binding var cameraEnabled: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var screenAwake = ScreenAwakeController()
    @State private var audioOutput = CallAudioOutput.current
    @State private var controlsVisible = true
    @State private var audioError = false
    #if DEBUG && targetEnvironment(simulator)
    @Environment(\.callSimulatorPreview) private var simulatorPreview
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            remoteVideo
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            Button {
                controlsVisible.toggle()
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controlsVisible ? "Hide call controls" : "Show call controls")
            .accessibilityIdentifier("reach.toggleCallControls")
        }
        .overlay(alignment: .topTrailing) {
            if cameraEnabled && hasLocalVideo {
                localVideo
                    .frame(width: 92, height: 124)
                    .background(.black)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.6)) }
                    .padding(14)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Your camera preview")
            }
        }
        .overlay(alignment: .topLeading) {
            if call.phase == .interrupted {
                Text("Reconnecting…")
                    .font(.subheadline.weight(.semibold))
                    .padding(10)
                    .background(.black.opacity(0.78), in: Capsule())
                    .padding(14)
                    .accessibilityIdentifier("reach.connectionStatus")
            }
        }
        .overlay(alignment: .bottom) {
            if controlsVisible { callControls }
        }
        .preferredColorScheme(.dark)
        #if DEBUG && targetEnvironment(simulator)
        .onAppear { controlsVisible = simulatorPreview != .hidden }
        #endif
        .onChange(of: keepsScreenAwake, initial: true) { _, keepAwake in
            if keepAwake {
                screenAwake.acquire(reason: "videoCall")
            } else {
                screenAwake.release(reason: "videoCall")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await call.end() } }
            if phase == .active { refreshAudioOutput() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { _ in
            refreshAudioOutput()
        }
        .onDisappear {
            screenAwake.releaseAll()
            Task {
                if call.peer === peer { await call.end() }
            }
        }
    }

    private var hasLocalVideo: Bool {
        #if DEBUG && targetEnvironment(simulator)
        if simulatorPreview != nil { return true }
        #endif
        return peer.localVideo != nil
    }

    @ViewBuilder private var remoteVideo: some View {
        #if DEBUG && targetEnvironment(simulator)
        if simulatorPreview != nil {
            SimulatorVideoPattern(title: "Partner video", detail: "SIMULATED VIDEO")
        } else {
            WebRTCVideoView(track: peer.remoteVideo)
        }
        #else
        WebRTCVideoView(track: peer.remoteVideo)
        #endif
    }

    @ViewBuilder private var localVideo: some View {
        #if DEBUG && targetEnvironment(simulator)
        if simulatorPreview != nil {
            SimulatorVideoPattern(title: "You", detail: nil)
        } else {
            WebRTCVideoView(track: peer.localVideo)
        }
        #else
        WebRTCVideoView(track: peer.localVideo)
        #endif
    }

    private var keepsScreenAwake: Bool {
        scenePhase == .active && call.phase.showsFullScreenCall
    }

    private var callControls: some View {
        VStack(spacing: 8) {
            Text(audioError ? "Couldn’t change audio output. \(audioOutput.title)" : audioOutput.title)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("reach.callAudioOutput")
            HStack(spacing: 12) {
                control(muted ? "Unmute microphone" : "Mute microphone",
                        icon: muted ? "mic.slash.fill" : "mic.fill", id: "reach.callMute") {
                    muted.toggle()
                    peer.setMuted(muted)
                }
                control(cameraEnabled ? "Stop sending video" : "Send video",
                        icon: cameraEnabled ? "video.fill" : "video.slash.fill", id: "reach.callVideo") {
                    cameraEnabled.toggle()
                    peer.setCameraEnabled(cameraEnabled)
                }
                control(call.speakerOverride ? "Use automatic audio routing" : "Use iPhone speaker",
                        icon: audioOutput == .speaker ? "speaker.wave.2.fill" : "speaker.fill", id: "reach.callSpeaker") {
                    do {
                        try call.setSpeakerOverride(!call.speakerOverride)
                        audioError = false
                        audioOutput = .current
                    } catch {
                        audioError = true
                        refreshAudioOutput()
                    }
                }
                control("End call", icon: "phone.down.fill", id: "reach.endCall", tint: .red) {
                    Task { await call.end() }
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func control(_ title: String, icon: String, id: String, tint: Color = .gray,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.8), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    private func refreshAudioOutput() {
        audioOutput = .current
        call.audioOutputChanged(to: audioOutput)
    }
}
