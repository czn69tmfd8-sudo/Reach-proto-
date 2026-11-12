import AVFoundation
@preconcurrency import WebRTC

enum CallAudioOutput: Equatable {
    case speaker, receiver, bluetooth, headphones, other, unavailable

    static var current: Self {
        Self(ports: AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType))
    }

    @MainActor
    static func setSpeakerOverride(_ enabled: Bool) throws {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }
        try session.overrideOutputAudioPort(enabled ? .speaker : .none)
    }

    init(ports: [AVAudioSession.Port]) {
        if ports.contains(where: { [.bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains($0) }) {
            self = .bluetooth
        } else if ports.contains(.headphones) {
            self = .headphones
        } else if ports.contains(.builtInSpeaker) {
            self = .speaker
        } else if ports.contains(.builtInReceiver) {
            self = .receiver
        } else {
            self = ports.isEmpty ? .unavailable : .other
        }
    }

    var title: String {
        switch self {
        case .speaker: return "iPhone speaker"
        case .receiver: return "iPhone receiver"
        case .bluetooth: return "Bluetooth audio"
        case .headphones: return "Headphones"
        case .other: return "External audio"
        case .unavailable: return "Audio output unavailable"
        }
    }
}
