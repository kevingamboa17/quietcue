import XCTest
@testable import MicPause

final class MicrophoneInUsePolicyTests: XCTestCase {
    private func process(
        pid: Int32 = 100,
        bundle: String? = "com.example.player",
        name: String = "Player",
        output: Bool = false
    ) -> MicrophoneProcess {
        MicrophoneProcess(
            pid: pid,
            bundleIdentifier: bundle,
            name: name,
            isRunningOutput: output
        )
    }

    private func media(
        bundle: String = "com.example.player",
        playing: Bool = true,
        pid: Int32? = 100
    ) -> MediaSnapshot {
        MediaSnapshot(
            bundleIdentifier: bundle,
            title: "Song",
            isPlaying: playing,
            contentIdentifier: "1",
            processIdentifier: pid
        )
    }

    func testIgnoresInputFromNowPlayingAppEvenWithOtherProcesses() {
        let detected: Set = [
            process(pid: 100, bundle: "com.spotify.client", name: "Spotify"),
            process(pid: 200, bundle: "com.zoom.Zoom", name: "zoom"),
        ]
        let filtered = MicrophoneInUsePolicy.processesInUse(
            detected: detected,
            nowPlaying: media(bundle: "com.spotify.client")
        )
        XCTAssertEqual(
            filtered,
            Set([process(pid: 200, bundle: "com.zoom.Zoom", name: "zoom")])
        )
    }

    func testIgnoresNowPlayingAppWithDifferentProcessID() {
        let detected: Set = [
            process(pid: 250, bundle: "com.apple.Music", name: "Music")
        ]
        let filtered = MicrophoneInUsePolicy.processesInUse(
            detected: detected,
            nowPlaying: media(bundle: "com.apple.Music", pid: 999)
        )
        XCTAssertTrue(filtered.isEmpty)
    }

    func testIgnoresDuplexOutputWhileNowPlayingIsPlaying() {
        let detected: Set = [
            process(pid: 250, bundle: "com.apple.Music", name: "Music", output: true)
        ]
        let filtered = MicrophoneInUsePolicy.processesInUse(
            detected: detected,
            nowPlaying: media(bundle: "com.apple.Music", pid: 999)
        )
        XCTAssertTrue(filtered.isEmpty)
    }

    func testKeepsUnrelatedMicrophoneProcesses() {
        let detected: Set = [process(pid: 200, bundle: "com.zoom.Zoom", name: "zoom")]
        let filtered = MicrophoneInUsePolicy.processesInUse(
            detected: detected,
            nowPlaying: media(bundle: "com.spotify.client", pid: 100)
        )
        XCTAssertEqual(filtered, detected)
    }

    func testIgnoresMediaRemoteUIServiceOnPlayback() {
        let detected: Set = [
            process(pid: 4489, bundle: "com.apple.MediaRemoteUIService", name: "Media Remote")
        ]
        let filtered = MicrophoneInUsePolicy.processesInUse(
            detected: detected,
            nowPlaying: media(bundle: "com.apple.Music", pid: 4451)
        )
        XCTAssertTrue(filtered.isEmpty)
    }
}