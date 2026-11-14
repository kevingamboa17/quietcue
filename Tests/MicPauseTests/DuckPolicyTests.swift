import XCTest
@testable import MicPause

final class DuckPolicyTests: XCTestCase {
    func testBeginsDuckWhenCurrentVolumeIsAboveTarget() {
        XCTAssertTrue(DuckPolicy.shouldBeginDuck(
            currentVolume: 0.8,
            isMuted: false,
            targetVolume: 0.2
        ))
    }

    func testDoesNotBeginDuckWhenAlreadyAtOrBelowTarget() {
        XCTAssertFalse(DuckPolicy.shouldBeginDuck(
            currentVolume: 0.15,
            isMuted: false,
            targetVolume: 0.2
        ))
        XCTAssertFalse(DuckPolicy.shouldBeginDuck(
            currentVolume: 0.2,
            isMuted: false,
            targetVolume: 0.2
        ))
    }

    func testDoesNotBeginDuckWhenOutputIsMuted() {
        XCTAssertFalse(DuckPolicy.shouldBeginDuck(
            currentVolume: 0.9,
            isMuted: true,
            targetVolume: 0.2
        ))
    }

    func testRestoresWhenVolumeStillMatchesDuckTarget() {
        XCTAssertTrue(DuckPolicy.shouldRestore(
            currentVolume: 0.2,
            duckedTo: 0.2,
            invalidated: false
        ))
    }

    func testDoesNotRestoreWhenUserChangedVolume() {
        XCTAssertFalse(DuckPolicy.shouldRestore(
            currentVolume: 0.55,
            duckedTo: 0.2,
            invalidated: false
        ))
    }

    func testDoesNotRestoreWhenVolumeCannotBeRead() {
        XCTAssertFalse(DuckPolicy.shouldRestore(
            currentVolume: nil,
            duckedTo: 0.2,
            invalidated: false
        ))
    }

    func testDoesNotRestoreInvalidatedDuck() {
        XCTAssertFalse(DuckPolicy.shouldRestore(
            currentVolume: 0.2,
            duckedTo: 0.2,
            invalidated: true
        ))
    }

    func testAppliedTargetNeverRaisesAboveOriginalVolume() {
        XCTAssertEqual(
            DuckPolicy.appliedTarget(originalVolume: 0.3, requestedTarget: 0.8),
            0.3
        )
        XCTAssertEqual(
            DuckPolicy.appliedTarget(originalVolume: 0.8, requestedTarget: 0.2),
            0.2
        )
    }
}
