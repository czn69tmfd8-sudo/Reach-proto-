import Foundation

@MainActor
final class PairObservationController: ObservableObject {
    @Published private(set) var presentation: PairSessionPresentation = .none
    @Published private(set) var lastError: String?

    private var observationTask: Task<Void, Never>?

    func start(
        partnership: Partnership,
        store: any ReachPairStore
    ) {
        stop()

        observationTask = Task {
            do {
                for try await pair in store.observePair(code: partnership.id) {
                    guard !Task.isCancelled else { return }

                    guard let pair else {
                        presentation = .none
                        continue
                    }

                    presentation = PairSessionInterpreter.presentation(
                        pair: pair,
                        partnership: partnership
                    )
                    lastError = nil
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                presentation = .none
                lastError = error.localizedDescription
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        presentation = .none
        lastError = nil
    }

    deinit {
        observationTask?.cancel()
    }
}
