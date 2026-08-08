import XCTest
@testable import MicPause

final class MicrophoneActivityMonitorTests: XCTestCase {
    func testMonitorDeliversInitialSnapshot() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15)

        let monitor = MicrophoneActivityMonitor()
        let expectation = expectation(description: "initial microphone snapshot")
        var receivedInitial = false

        monitor.onUpdate = { _, isInitial in
            receivedInitial = isInitial
            expectation.fulfill()
        }
        monitor.start()
        wait(for: [expectation], timeout: 2)
        monitor.stop()

        XCTAssertTrue(receivedInitial)
    }
}
