import AVFoundation

/// Preserve Bluetooth hands-free input/output on both supported Xcode SDKs.
enum ReachAudioConfiguration {
    static var callOptions: AVAudioSession.CategoryOptions {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return [.defaultToSpeaker, .allowBluetoothHFP]
        } else {
            return [.defaultToSpeaker, .allowBluetooth]
        }
        #else
        // The HFP-specific spelling is absent from older SDKs. This option
        // authorizes the same hands-free audio route, including microphone input.
        return [.defaultToSpeaker, .allowBluetooth]
        #endif
    }
}
