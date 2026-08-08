import AppKit
import Foundation

struct MediaSnapshot: Equatable, Sendable {
    let bundleIdentifier: String
    let title: String
    let isPlaying: Bool
    let contentIdentifier: String?
    let processIdentifier: Int32?

    var identity: String {
        // Some players (notably Spotify on this macOS build) emit a different
        // contentItemIdentifier on successive reads of the same track. The
        // player/title pair is stable enough for ownership checks and still
        // changes when the user switches to another track.
        return "\(bundleIdentifier)|\(title)"
    }

    var applicationName: String {
        if let processIdentifier,
           let application = NSRunningApplication(processIdentifier: processIdentifier) {
            return application.localizedName ?? bundleIdentifier
        }
        return bundleIdentifier
    }

    static func fromAdapterPayload(_ payload: [String: Any]) -> MediaSnapshot? {
        guard let bundleIdentifier = payload["bundleIdentifier"] as? String,
              let title = payload["title"] as? String,
              let isPlaying = payload["playing"] as? Bool else {
            return nil
        }

        let contentIdentifier = payload["contentItemIdentifier"] as? String
        let processIdentifier: Int32?
        if let number = payload["processIdentifier"] as? NSNumber {
            processIdentifier = number.int32Value
        } else {
            processIdentifier = nil
        }

        return MediaSnapshot(
            bundleIdentifier: bundleIdentifier,
            title: title,
            isPlaying: isPlaying,
            contentIdentifier: contentIdentifier,
            processIdentifier: processIdentifier
        )
    }
}

enum MediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
}
