import SwiftUI
import UIKit

@MainActor
enum ReachKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func reachKeyboardToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { ReachKeyboard.dismiss() }
                    .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
}

/// Observes taps without cancelling buttons, scrolling, or text selection.
/// A tap within a text input must retain focus; other taps dismiss the keyboard.
struct ReachKeyboardObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardObserverView { KeyboardObserverView() }
    func updateUIView(_ uiView: KeyboardObserverView, context: Context) {}
    static func dismantleUIView(_ uiView: KeyboardObserverView, coordinator: ()) { uiView.detach() }

    @MainActor
    final class KeyboardObserverView: UIView, @preconcurrency UIGestureRecognizerDelegate {
        private weak var observedWindow: UIWindow?
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        override func didMoveToWindow() {
            super.didMoveToWindow()
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = window
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window?.addGestureRecognizer(tap)
        }
        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
        }
        @objc private func dismissKeyboard() { ReachKeyboard.dismiss() }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var ancestor = touch.view
            while let view = ancestor {
                if view is UITextField || view is UITextView { return false }
                ancestor = view.superview
            }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
