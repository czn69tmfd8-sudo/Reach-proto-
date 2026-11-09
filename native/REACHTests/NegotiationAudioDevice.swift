import Foundation
@preconcurrency import WebRTC

/// Hardware-independent audio I/O for SDP negotiation tests only. No system audio
/// unit, microphone, or AVAudioSession is opened on a headless build machine.
/// Tracks, codecs, offer/answer and peer shutdown remain real SDK operations.
/// This device deliberately does not generate or verify PCM/media transport.
final class NegotiationAudioDevice: NSObject, RTCAudioDevice {
    let deviceInputSampleRate = 48_000.0
    let inputIOBufferDuration = 0.01
    let inputNumberOfChannels = 1
    let inputLatency = 0.0
    let deviceOutputSampleRate = 48_000.0
    let outputIOBufferDuration = 0.01
    let outputNumberOfChannels = 1
    let outputLatency = 0.0

    private let lock = NSLock()
    private var initialized = false
    private var playoutInitialized = false
    private var recordingInitialized = false
    private var playing = false
    private var recording = false
    private var initializationCount = 0

    private func read<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
    var isInitialized: Bool { read { initialized } }
    var isPlayoutInitialized: Bool { read { playoutInitialized } }
    var isRecordingInitialized: Bool { read { recordingInitialized } }
    var isPlaying: Bool { read { playing } }
    var isRecording: Bool { read { recording } }
    var didInitialize: Bool { read { initializationCount > 0 } }

    func initialize(with delegate: any RTCAudioDeviceDelegate) -> Bool {
        read { initialized = true; initializationCount += 1 }
        return true
    }
    func terminateDevice() -> Bool {
        read {
            initialized = false; playoutInitialized = false; recordingInitialized = false
            playing = false; recording = false
        }
        return true
    }
    func initializePlayout() -> Bool { read { playoutInitialized = initialized; return playoutInitialized } }
    func initializeRecording() -> Bool { read { recordingInitialized = initialized; return recordingInitialized } }
    func startPlayout() -> Bool { read { playing = playoutInitialized; return playing } }
    func stopPlayout() -> Bool { read { playing = false }; return true }
    func startRecording() -> Bool { read { recording = recordingInitialized; return recording } }
    func stopRecording() -> Bool { read { recording = false }; return true }
}
