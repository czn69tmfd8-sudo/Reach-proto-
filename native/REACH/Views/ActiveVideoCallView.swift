import AVFoundation
import Combine
import SwiftUI

struct ActiveVideoCallView: View {
    @ObservedObject var call: StagingCallController
    @ObservedObject var peer: NativeWebRTCPeer

    @Environment(\.scenePhase) private var scenePhase
    @State private var screenAwake = ScreenAwakeController()
    @State private var audioOutput = CallAudioOutput.current
    @State private var controlsVisible = true
    @State private var audioError = false
    @State private var audioInterrupted = false
    @State private var requestedOutput: CallAudioOutput?
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
            if peer.cameraEnabled && hasLocalVideo {
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
            if phase == .background { Task { await call.end(backgrounded: true) } }
            if phase == .active { refreshAudioOutput() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main)) { _ in
            refreshAudioOutput()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main)) { notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            audioInterrupted = type == .began
            if type == .ended {
                let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    call.restoreAudioRoute()
                }
            }
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
            Text(audioStatus)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("reach.callAudioOutput")
            HStack(spacing: 12) {
                control(peer.muted ? "Unmute microphone" : "Mute microphone",
                        icon: peer.muted ? "mic.slash.fill" : "mic.fill", id: "reach.callMute") {
                    peer.setMuted(!peer.muted)
                }
                control(peer.cameraEnabled ? "Stop sending video" : "Send video",
                        icon: peer.cameraEnabled ? "video.fill" : "video.slash.fill", id: "reach.callVideo") {
                    peer.setCameraEnabled(!peer.cameraEnabled)
                }
                audioRouteControl
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

    private var audioStatus: String {
        if audioInterrupted { return "Audio interrupted. \(audioOutput.title)" }
        if audioError { return "Couldn’t change audio output. \(audioOutput.title)" }
        if requestedOutput != nil { return "Requested audio output is not active. \(audioOutput.title)" }
        return audioOutput.title
    }

    private var audioRouteControl: some View {
        Menu {
            Button("Automatic") { selectAudioRoute(.automatic) }
            Button("iPhone speaker") { selectAudioRoute(.speaker) }
            Button("iPhone receiver") { selectAudioRoute(.receiver) }
            ForEach(CallAudioRoute.bluetoothInputs, id: \.uid) { device in
                Button(device.portName) { selectAudioRoute(.bluetooth(device.uid)) }
            }
        } label: {
            Image(systemName: audioOutput == .speaker ? "speaker.wave.2.fill" : "speaker.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 48, height: 48)
                .background(.gray.opacity(0.8), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(audioInterrupted)
        .accessibilityLabel("Audio output")
        .accessibilityValue(audioOutput.title)
        .accessibilityIdentifier("reach.callSpeaker")
    }

    private func selectAudioRoute(_ route: CallAudioRoute) {
        do {
            try call.setAudioRoute(route)
            requestedOutput = route.expectedOutput
            audioError = false
        } catch {
            requestedOutput = nil
            audioError = true
        }
        refreshAudioOutput()
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
        if audioOutput == requestedOutput { requestedOutput = nil }
    }
}
