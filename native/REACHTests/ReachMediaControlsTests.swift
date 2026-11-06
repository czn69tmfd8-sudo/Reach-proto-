import XCTest
@testable import REACH

final class ReachMediaControlsTests: XCTestCase {
    func testMutedDuringSetupNeverEnablesNewMicrophone() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            controls.setMuted(true)
            var writes: [Bool] = []
            controls.bindMicrophone { writes.append($0) }
            XCTAssertEqual(writes, [false])
            controls.setMuted(false)
            XCTAssertEqual(writes, [false, true])
        }
    }

    func testVideoDisabledDuringSetupNeverEnablesNewTrack() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            controls.setCameraEnabled(false)
            var writes: [Bool] = []
            controls.bindCamera { writes.append($0) }
            XCTAssertEqual(writes, [false])
            controls.setCameraEnabled(true)
            XCTAssertEqual(writes, [false, true])
        }
    }

    func testLatestSetupChoiceAndIndependentAudioVideoControls() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            controls.setMuted(true); controls.setMuted(false)
            controls.setCameraEnabled(false)
            var audio: [Bool] = [], video: [Bool] = []
            controls.bindMicrophone { audio.append($0) }
            controls.bindCamera { video.append($0) }
            controls.setMuted(true)
            XCTAssertEqual(audio, [true, false]); XCTAssertEqual(video, [false])
        }
    }

    func testEndDisablesBothTracksAndCannotBeUndoneByLateToggles() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            var audio: [Bool] = [], video: [Bool] = []
            controls.bindMicrophone { audio.append($0) }
            controls.bindCamera { video.append($0) }
            controls.close(); controls.close()
            controls.setMuted(false); controls.setCameraEnabled(true)
            XCTAssertEqual(audio, [true, false]); XCTAssertEqual(video, [true, false])
        }
    }

    func testTracksCreatedAfterEndAreImmediatelyDisabled() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            controls.close()
            var writes: [Bool] = []
            controls.bindMicrophone { writes.append($0) }
            controls.bindCamera { writes.append($0) }
            XCTAssertEqual(writes, [false, false])
        }
    }

    func testReplacingTrackDisablesOldTrackAndAppliesCurrentChoice() {
        MainActor.assumeIsolated {
            let controls = ReachMediaControls()
            var old: [Bool] = [], new: [Bool] = []
            controls.bindCamera { old.append($0) }
            controls.setCameraEnabled(false)
            controls.bindCamera { new.append($0) }
            controls.setCameraEnabled(true)
            XCTAssertEqual(old, [true, false, false]); XCTAssertEqual(new, [false, true])
        }
    }
}
