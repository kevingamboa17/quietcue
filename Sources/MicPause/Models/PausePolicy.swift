import Foundation

enum PausePolicy {
    static func shouldRestore(
        sessionIdentity: String,
        currentMedia: MediaSnapshot?,
        invalidated: Bool,
        microphoneIsActive: Bool,
        allowWhileMicrophoneActive: Bool
    ) -> Bool {
        guard (allowWhileMicrophoneActive || !microphoneIsActive),
              !invalidated,
              let currentMedia,
              currentMedia.identity == sessionIdentity,
              !currentMedia.isPlaying else {
            return false
        }
        return true
    }
}
