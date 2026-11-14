import Foundation

enum MicActionMode: String, CaseIterable, Identifiable {
    case pause
    case duck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pause:
            return "Pause"
        case .duck:
            return "Lower volume"
        }
    }

    static func persisted(from defaults: UserDefaults = .standard) -> MicActionMode {
        guard let raw = defaults.string(forKey: Keys.actionMode),
              let mode = MicActionMode(rawValue: raw) else {
            return .pause
        }
        return mode
    }

    static func persistedDuckVolume(from defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.object(forKey: Keys.duckVolume) as? Double ?? 0.2
        return min(1, max(0, stored))
    }

    enum Keys {
        static let actionMode = "MicPause.actionMode"
        static let duckVolume = "MicPause.duckVolume"
    }
}
