import XCTest
import UIKit
@testable import REACH

final class ReachUIBehaviorTests: XCTestCase {
    @MainActor func testTextFieldAndItsSubviewsKeepFocusOnTap() async {
        let field = UITextField(), child = UIView()
        field.addSubview(child)
        XCTAssertFalse(ReachKeyboard.shouldDismiss(touching: field))
        XCTAssertFalse(ReachKeyboard.shouldDismiss(touching: child))
    }
    @MainActor func testMultilineTextAndSelectionSubviewsKeepFocus() async {
        let text = UITextView(), child = UIView()
        text.addSubview(child)
        XCTAssertFalse(ReachKeyboard.shouldDismiss(touching: text))
        XCTAssertFalse(ReachKeyboard.shouldDismiss(touching: child))
    }
    @MainActor func testOutsideControlsDismissButUnknownTouchesDoNot() async {
        XCTAssertTrue(ReachKeyboard.shouldDismiss(touching: UIButton(type: .system)))
        XCTAssertTrue(ReachKeyboard.shouldDismiss(touching: UILabel()))
        XCTAssertFalse(ReachKeyboard.shouldDismiss(touching: nil))
    }
    @MainActor func testObserverDetachesWithoutLeavingWindowGestureBehind() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let before = window.gestureRecognizers?.count ?? 0
        let observer = ReachKeyboardObserver.KeyboardObserverView(frame: .zero)
        window.addSubview(observer)
        XCTAssertEqual(window.gestureRecognizers?.count ?? 0, before + 1)
        observer.detach()
        XCTAssertEqual(window.gestureRecognizers?.count ?? 0, before)
        observer.removeFromSuperview()
        XCTAssertEqual(window.gestureRecognizers?.count ?? 0, before)
    }
    func testRemoteErrorPayloadNeverBecomesDisplayCopy() {
        let error = NSError(domain: "FIRFirestoreErrorDomain", code: 14,
                            userInfo: [NSLocalizedDescriptionKey: "secret pair ID and SDP payload"])
        let message = ReachErrorPresentation.message(error)
        XCTAssertTrue(message.contains("reached"))
        XCTAssertFalse(message.contains("secret")); XCTAssertFalse(message.contains("SDP"))
    }
    func testPermissionAndExpiredRoomErrorsRemainActionable() {
        XCTAssertTrue(ReachErrorPresentation.message(PeerError.permission).contains("Settings"))
        XCTAssertTrue(ReachErrorPresentation.message(SignalingError.ended).contains("expired"))
        XCTAssertTrue(ReachErrorPresentation.message(ReachRoomCoordinatorError.staleSession("private-room-id")).contains("stale"))
        XCTAssertFalse(ReachErrorPresentation.message(ReachRoomCoordinatorError.staleSession("private-room-id")).contains("private-room-id"))
    }
}
