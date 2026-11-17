import AVFoundation
import XCTest
@testable import REACH

final class CallPresentationTests: XCTestCase {
    func testFullScreenPersistsDuringRecoveryAndEndsOnTeardown() {
        var phase = ReachCallPhase.outgoing
        XCTAssertFalse(phase.showsFullScreenCall)
        phase = phase.receiving(.negotiationStarted)
        XCTAssertFalse(phase.showsFullScreenCall)
        phase = phase.receiving(.connected)
        XCTAssertTrue(phase.showsFullScreenCall)
        phase = phase.receiving(.disconnected)
        XCTAssertTrue(phase.showsFullScreenCall)
        XCTAssertTrue(phase.receiving(.connected).showsFullScreenCall)
        XCTAssertFalse(ReachCallPhase.ending.showsFullScreenCall)
        XCTAssertFalse(ReachCallPhase.failed("Timed out").showsFullScreenCall)
    }

    #if DEBUG && targetEnvironment(simulator)
    @MainActor
    func testOfflineSimulatorCallKeepsOnePeerAndEndsCleanly() async throws {
        let call = StagingCallController()
        call.connectSimulatorPreview()
        XCTAssertEqual(call.phase, .connected)
        let peer = try XCTUnwrap(call.peer)
        peer.setMuted(true)
        peer.setCameraEnabled(false)
        call.connectSimulatorPreview()
        XCTAssertTrue(call.peer === peer)
        XCTAssertTrue(peer.muted)
        XCTAssertFalse(peer.cameraEnabled)
        await call.end()
        XCTAssertEqual(call.phase, .idle)
        XCTAssertNil(call.peer)
        XCTAssertTrue(peer.muted)
        XCTAssertFalse(peer.cameraEnabled)
    }
    #endif

    func testAudioOutputDistinguishesReceiverSpeakerAndAccessories() {
        XCTAssertEqual(CallAudioOutput(ports: [.builtInReceiver]), .receiver)
        XCTAssertEqual(CallAudioOutput(ports: [.builtInSpeaker]), .speaker)
        XCTAssertEqual(CallAudioOutput(ports: [.headphones]), .headphones)
        XCTAssertEqual(CallAudioOutput(ports: [.bluetoothHFP]), .bluetooth)
        XCTAssertEqual(CallAudioOutput(ports: [.bluetoothA2DP]), .bluetooth)
        XCTAssertEqual(CallAudioOutput(ports: [.usbAudio]), .other)
        XCTAssertEqual(CallAudioOutput(ports: []), .unavailable)
    }

    func testAudioRoutingPreservesTheCallDefaultAndCanRequestReceiver() {
        XCTAssertEqual(CallAudioRoute.automatic.mode, .videoChat)
        XCTAssertEqual(CallAudioRoute.automatic.categoryOptions, ReachAudioConfiguration.callOptions)
        XCTAssertEqual(CallAudioRoute.receiver.mode, .voiceChat)
        XCTAssertFalse(CallAudioRoute.receiver.categoryOptions.contains(.defaultToSpeaker))
        XCTAssertEqual(CallAudioRoute.receiver.categoryOptions,
                       ReachAudioConfiguration.callOptions.subtracting(.defaultToSpeaker))
        XCTAssertNil(CallAudioRoute.automatic.expectedOutput)
        XCTAssertEqual(CallAudioRoute.speaker.expectedOutput, .speaker)
        XCTAssertEqual(CallAudioRoute.receiver.expectedOutput, .receiver)
        XCTAssertEqual(CallAudioRoute.bluetooth("test").expectedOutput, .bluetooth)
    }
}
