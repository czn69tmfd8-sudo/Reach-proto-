import Foundation

@MainActor
final class ReachMediaSessionController: ObservableObject {
    @Published private(set) var runtime = ReachRuntimeState()
    @Published private(set) var health: ReachConnectionHealth = .idle

    private let media: NativeMediaService

    init(media: NativeMediaService = NativeMediaService()) {
        self.media = media
    }

    func prepare() async throws {
        runtime.media = .preparing
        refreshHealth()

        do {
            try await media.prepare()
            runtime.media = .connecting
            refreshHealth()
        } catch {
            runtime.media = .failed(error.localizedDescription)
            refreshHealth()
            throw error
        }
    }

    func signalingChanged(_ state: ReachSignalingState) {
        runtime.signaling = state
        refreshHealth()
    }

    func mediaConnected() {
        runtime.media = .connected
        refreshHealth()
    }

    func mediaInterrupted() {
        runtime.media = .interrupted
        refreshHealth()
    }

    func mediaFailed(_ reason: String) {
        runtime.media = .failed(reason)
        refreshHealth()
    }

    func stop() {
        media.stop()
        runtime = ReachRuntimeState()
        refreshHealth()
    }

    private func refreshHealth() {
        health = ReachConnectionHealthPolicy.evaluate(
            signaling: runtime.signaling,
            media: runtime.media
        )
    }
}
