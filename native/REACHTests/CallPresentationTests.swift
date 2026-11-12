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
        call.connectSimulatorPreview()
        XCTAssertTrue(call.peer === peer)
        await call.end()
        XCTAssertEqual(call.phase, .idle)
        XCTAssertNil(call.peer)
        XCTAssertFalse(call.speakerOverride)
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

    func testWebRTCCallOptionsRequestTheSpeakerDefault() {
        XCTAssertTrue(ReachAudioConfiguration.callOptions.contains(.defaultToSpeaker))
    }
}
