import AVFoundation
@preconcurrency import WebRTC

enum CallAudioOutput: Equatable {
    case speaker, receiver, bluetooth, headphones, other, unavailable

    static var current: Self {
        Self(ports: AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType))
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

enum CallAudioRoute: Equatable {
    case automatic, speaker, receiver, bluetooth(String)

    var expectedOutput: CallAudioOutput? {
        switch self {
        case .automatic: return nil
        case .speaker: return .speaker
        case .receiver: return .receiver
        case .bluetooth: return .bluetooth
        }
    }

    // videoChat adds defaultToSpeaker automatically. Use voice processing
    // in voiceChat mode when requesting the built-in receiver.
    var mode: AVAudioSession.Mode { self == .receiver ? .voiceChat : .videoChat }
    var categoryOptions: AVAudioSession.CategoryOptions {
        self == .receiver ? ReachAudioConfiguration.callOptions.subtracting(.defaultToSpeaker) : ReachAudioConfiguration.callOptions
    }

    @MainActor
    static var bluetoothInputs: [AVAudioSessionPortDescription] {
        (AVAudioSession.sharedInstance().availableInputs ?? []).filter { $0.portType == .bluetoothHFP }
    }

    @MainActor
    func apply() throws {
        let system = AVAudioSession.sharedInstance()
        let rtc = RTCAudioSession.sharedInstance()
        rtc.lockForConfiguration()
        defer { rtc.unlockForConfiguration() }

        let input: AVAudioSessionPortDescription?
        switch self {
        case .receiver:
            guard let builtIn = system.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                throw RouteUnavailable()
            }
            input = builtIn
        case .bluetooth(let uid):
            guard let device = Self.bluetoothInputs.first(where: { $0.uid == uid }) else { throw RouteUnavailable() }
            input = device
        case .automatic, .speaker:
            input = nil
        }

        if system.mode != mode { try rtc.setMode(mode) }
        if system.category != .playAndRecord || system.categoryOptions != categoryOptions {
            try rtc.setCategory(.playAndRecord, with: categoryOptions)
        }
        if self != .speaker { try rtc.overrideOutputAudioPort(.none) }
        if system.preferredInput?.uid != input?.uid {
            if let input { try rtc.setPreferredInput(input) }
            else {
                // WebRTC's wrapper imports a non-optional input. Clear the
                // preference through AVAudioSession while holding its RTC lock.
                try system.setPreferredInput(nil)
            }
        }
        if self == .speaker { try rtc.overrideOutputAudioPort(.speaker) }
    }

    private struct RouteUnavailable: Error {}
}
