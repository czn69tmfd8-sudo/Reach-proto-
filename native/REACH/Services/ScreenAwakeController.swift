import UIKit

@MainActor
final class ScreenAwakeController {
    private var reasons = Set<String>()

    func acquire(reason: String) {
        reasons.insert(reason)
        apply()
    }

    func release(reason: String) {
        reasons.remove(reason)
        apply()
    }

    func releaseAll() {
        reasons.removeAll()
        apply()
    }

    private func apply() {
        UIApplication.shared.isIdleTimerDisabled = !reasons.isEmpty
    }
}
