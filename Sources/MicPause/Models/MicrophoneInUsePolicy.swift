import Foundation

enum MicrophoneInUsePolicy {
    static let quietCueBundleIdentifier = "com.local.MicPause"

    /// macOS starts this helper around Now Playing changes; it reports `isRunningInput` during playback.
    private static let ignoredInputBundleIdentifiers: Set<String> = [
        "com.apple.MediaRemoteUIService",
    ]

    /// CoreAudio often marks the Now Playing app as `isRunningInput` during ordinary playback.
    /// Drop those detections so playback is not treated as microphone use.
    static func processesInUse(
        detected: Set<MicrophoneProcess>,
        nowPlaying: MediaSnapshot?
    ) -> Set<MicrophoneProcess> {
        guard !detected.isEmpty else { return detected }

        return Set(detected.filter { process in
            if isQuietCueProcess(process) || isIgnoredIncidentalSystemInput(process) {
                return false
            }
            guard let nowPlaying else { return true }
            return !isIncidentalPlaybackInput(process: process, nowPlaying: nowPlaying)
        })
    }

    static func isQuietCueProcess(_ process: MicrophoneProcess) -> Bool {
        process.bundleIdentifier == quietCueBundleIdentifier
    }

    static func isIgnoredIncidentalSystemInput(_ process: MicrophoneProcess) -> Bool {
        guard let bundle = process.bundleIdentifier else { return false }
        if ignoredInputBundleIdentifiers.contains(bundle) {
            return true
        }
        let lowered = bundle.lowercased()
        return lowered.contains("mediaremote") && bundle.hasPrefix("com.apple.")
    }

    static func isIncidentalPlaybackInput(
        process: MicrophoneProcess,
        nowPlaying: MediaSnapshot
    ) -> Bool {
        if matchesNowPlayingApp(process, nowPlaying) {
            return true
        }

        if process.name.caseInsensitiveCompare(nowPlaying.applicationName) == .orderedSame {
            return true
        }

        guard nowPlaying.isPlaying, process.isRunningOutput else { return false }

        if let processBundle = process.bundleIdentifier,
           processBundle == nowPlaying.bundleIdentifier {
            return true
        }

        return process.name.caseInsensitiveCompare(nowPlaying.applicationName) == .orderedSame
    }

    static func matchesNowPlayingApp(
        _ process: MicrophoneProcess,
        _ nowPlaying: MediaSnapshot
    ) -> Bool {
        if let mediaPID = nowPlaying.processIdentifier, process.pid == mediaPID {
            return true
        }

        if let processBundle = process.bundleIdentifier,
           processBundle == nowPlaying.bundleIdentifier {
            return true
        }

        return false
    }
}