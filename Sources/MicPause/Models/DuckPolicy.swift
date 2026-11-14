import Foundation

enum DuckPolicy {
    static let volumeTolerance: Float = 0.02

    static func shouldBeginDuck(currentVolume: Float, isMuted: Bool, targetVolume: Float) -> Bool {
        guard !isMuted else { return false }
        return currentVolume > targetVolume + volumeTolerance
    }

    static func shouldRestore(
        currentVolume: Float?,
        duckedTo: Float,
        invalidated: Bool
    ) -> Bool {
        guard !invalidated, let currentVolume else { return false }
        return abs(currentVolume - duckedTo) <= volumeTolerance
    }

    static func appliedTarget(originalVolume: Float, requestedTarget: Float) -> Float {
        min(originalVolume, max(0, min(1, requestedTarget)))
    }
}
