/// Retain user choices across asynchronous permission/factory/camera setup.
/// Bindings run on MainActor before a track is attached to the peer connection.
@MainActor
final class ReachMediaControls {
    private var microphoneEnabled = true
    private var cameraEnabled = true
    private var closed = false
    private var microphone: ((Bool) -> Void)?
    private var camera: ((Bool) -> Void)?

    func setMuted(_ muted: Bool) {
        guard !closed else { return }
        microphoneEnabled = !muted
        microphone?(microphoneEnabled)
    }

    func setCameraEnabled(_ enabled: Bool) {
        guard !closed else { return }
        cameraEnabled = enabled
        camera?(enabled)
    }

    func bindMicrophone(_ setEnabled: @escaping (Bool) -> Void) {
        guard !closed else { setEnabled(false); return }
        microphone?(false)
        microphone = setEnabled
        setEnabled(microphoneEnabled)
    }

    func bindCamera(_ setEnabled: @escaping (Bool) -> Void) {
        guard !closed else { setEnabled(false); return }
        camera?(false)
        camera = setEnabled
        setEnabled(cameraEnabled)
    }

    func close() {
        guard !closed else { return }
        closed = true
        microphone?(false); camera?(false)
        microphone = nil; camera = nil
    }
}
