import XCTest
@testable import MicPause

final class PausePolicyTests: XCTestCase {
    private let playing = MediaSnapshot(
        bundleIdentifier: "com.spotify.client",
        title: "Track",
        isPlaying: true,
        contentIdentifier: "track-1",
        processIdentifier: 42
    )

    private let paused = MediaSnapshot(
        bundleIdentifier: "com.spotify.client",
        title: "Track",
        isPlaying: false,
        contentIdentifier: "track-1",
        processIdentifier: 42
    )

    func testRestoresTheSamePausedSessionWhenMicrophoneIsIdle() {
        XCTAssertTrue(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: paused,
            invalidated: false,
            microphoneIsActive: false,
            allowWhileMicrophoneActive: false
        ))
    }

    func testRestoresWhenPlayerChangesOnlyItsUnstableContentIdentifier() {
        let laterSnapshot = MediaSnapshot(
            bundleIdentifier: "com.spotify.client",
            title: "Track",
            isPlaying: false,
            contentIdentifier: "another-unstable-id",
            processIdentifier: 42
        )

        XCTAssertTrue(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: laterSnapshot,
            invalidated: false,
            microphoneIsActive: false,
            allowWhileMicrophoneActive: false
        ))
    }

    func testDoesNotRestoreWhenMediaChanged() {
        XCTAssertFalse(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: playing,
            invalidated: false,
            microphoneIsActive: false,
            allowWhileMicrophoneActive: false
        ))
    }

    func testDoesNotRestoreWhenMicrophoneIsStillActive() {
        XCTAssertFalse(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: paused,
            invalidated: false,
            microphoneIsActive: true,
            allowWhileMicrophoneActive: false
        ))
    }

    func testQuitCanRestoreWhileMicrophoneIsActive() {
        XCTAssertTrue(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: paused,
            invalidated: false,
            microphoneIsActive: true,
            allowWhileMicrophoneActive: true
        ))
    }

    func testInvalidatedSessionNeverRestores() {
        XCTAssertFalse(PausePolicy.shouldRestore(
            sessionIdentity: paused.identity,
            currentMedia: paused,
            invalidated: true,
            microphoneIsActive: false,
            allowWhileMicrophoneActive: true
        ))
    }
}
