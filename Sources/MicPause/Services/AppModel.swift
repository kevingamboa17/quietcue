import AppKit
import Combine
import Foundation
import OSLog
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var microphoneProcesses: [MicrophoneProcess] = []
    @Published private(set) var currentMedia: MediaSnapshot?
    @Published private(set) var statusText = "Waiting for microphone"
    @Published private(set) var mediaStatus = "Connecting to media controls"
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var actionMode: MicActionMode
    @Published private(set) var duckVolume: Double
    @Published var isEnabled: Bool

    private let logger = Logger(subsystem: "com.local.MicPause", category: "coordinator")
    private let microphoneMonitor = MicrophoneActivityMonitor()
    private let mediaClient = MediaRemoteClient()
    private let volumeController = SystemVolumeController()

    private var microphoneIsActive = false
    private var baselineReady = false
    private var ownedPause: OwnedPause?
    private var ownedDuck: OwnedDuck?
    private var previewDuck: OwnedDuck?
    private var previewRestoreTask: Task<Void, Never>?
    private var previewDebounceTask: Task<Void, Never>?
    private var isSliderEditing = false
    private let previewIdleDelayNanoseconds: UInt64 = 700_000_000
    private let previewHoldNanoseconds: UInt64 = 3_000_000_000

    private struct OwnedPause: Sendable {
        let identity: String
        let applicationName: String
        let title: String
        var pauseConfirmed = false
        var invalidated = false
    }

    private struct OwnedDuck {
        let original: SystemVolumeSnapshot
        var duckedTo: Float
        var invalidated = false
    }

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "MicPause.enabled") as? Bool ?? true
        actionMode = MicActionMode.persisted()
        duckVolume = MicActionMode.persistedDuckVolume()
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

        mediaClient.onSnapshot = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.handleMediaUpdate(snapshot)
            }
        }
        microphoneMonitor.onUpdate = { [weak self] processes, isInitial in
            self?.handleMicrophoneUpdate(processes, isInitial: isInitial)
        }

        mediaStatus = mediaClient.isAvailable ? "Media controls connected" : "Media controls unavailable"
        mediaClient.startStream()
        microphoneMonitor.start()
    }

    deinit {
        microphoneMonitor.stop()
        mediaClient.stopStream()
    }

    var microphoneSummary: String {
        guard !microphoneProcesses.isEmpty else { return "Not detected" }
        let names = microphoneProcesses.map(\.name)
        if names.count == 1 { return names[0] }
        return "\(names[0]) and \(names.count - 1) more"
    }

    var isMicrophoneActive: Bool {
        microphoneIsActive
    }

    var isPauseSessionActive: Bool {
        ownedPause != nil
    }

    var isDuckSessionActive: Bool {
        ownedDuck != nil
    }

    var mediaSummary: String {
        guard let currentMedia else { return "No media playing" }
        let state = currentMedia.isPlaying ? "Playing" : "Paused"
        return "\(currentMedia.applicationName) · \(state)"
    }

    var duckVolumePercent: Int {
        Int((duckVolume * 100).rounded())
    }

    var menuSymbol: String {
        if !isEnabled { return "mic.slash" }
        if microphoneIsActive { return "mic.fill" }
        if ownedPause != nil { return "pause.circle.fill" }
        if ownedDuck != nil { return "speaker.wave.1.fill" }
        return "mic"
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "MicPause.enabled")

        if !enabled {
            let pauseSession = ownedPause
            ownedPause = nil
            let duckSession = ownedDuck
            ownedDuck = nil
            baselineReady = false
            statusText = "Auto pause is off"
            endVolumePreview(restore: true)
            if let pauseSession {
                restoreIfSafe(pauseSession, reason: "feature disabled", allowWhileMicrophoneActive: true)
            }
            if let duckSession {
                restoreDuckIfSafe(duckSession)
            }
        } else {
            baselineReady = microphoneProcesses.isEmpty
            statusText = baselineReady ? "Waiting for microphone" : "Waiting for current microphone use to end"
        }
    }

    func setActionMode(_ mode: MicActionMode) {
        guard mode != actionMode else { return }
        actionMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: MicActionMode.Keys.actionMode)
        endVolumePreview(restore: true)

        guard isEnabled, baselineReady, microphoneIsActive else { return }

        let pauseSession = ownedPause
        ownedPause = nil
        let duckSession = ownedDuck
        ownedDuck = nil
        if let pauseSession {
            restoreIfSafe(pauseSession, reason: "action mode changed", allowWhileMicrophoneActive: true)
        }
        if let duckSession {
            restoreDuckIfSafe(duckSession)
        }

        beginActionSession()
    }

    func setDuckVolume(_ volume: Double) {
        let clamped = min(1, max(0, volume))
        duckVolume = clamped
        UserDefaults.standard.set(clamped, forKey: MicActionMode.Keys.duckVolume)

        if var session = ownedDuck, !session.invalidated {
            let target = DuckPolicy.appliedTarget(
                originalVolume: session.original.volume,
                requestedTarget: Float(clamped)
            )

            if !DuckPolicy.shouldBeginDuck(
                currentVolume: session.original.volume,
                isMuted: session.original.isMuted,
                targetVolume: target
            ) {
                ownedDuck = nil
                restoreDuckIfSafe(session)
                return
            }

            guard volumeController.setVolume(target) else { return }
            session.duckedTo = target
            ownedDuck = session
            statusText = "Volume lowered to \(percentString(target))"
            return
        }

        schedulePreviewAfterSliderSettles()
    }

    func setDuckSliderEditing(_ editing: Bool) {
        isSliderEditing = editing
        previewDebounceTask?.cancel()
        previewDebounceTask = nil
        if editing {
            endVolumePreview(restore: true)
            return
        }
        startVolumePreview()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            logger.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    func quit() {
        let pauseSession = ownedPause
        ownedPause = nil
        let duckSession = ownedDuck
        ownedDuck = nil
        endVolumePreview(restore: true)
        if let pauseSession {
            restoreIfSafe(pauseSession, reason: "app quit", allowWhileMicrophoneActive: true)
        }
        if let duckSession {
            restoreDuckIfSafe(duckSession)
        }
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    private func handleMicrophoneUpdate(_ processes: Set<MicrophoneProcess>, isInitial: Bool) {
        microphoneProcesses = processes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let wasActive = microphoneIsActive
        microphoneIsActive = !processes.isEmpty

        if isInitial {
            baselineReady = !microphoneIsActive
            statusText = baselineReady ? "Waiting for microphone" : "Waiting for current microphone use to end"
            return
        }

        guard isEnabled else { return }

        if !baselineReady {
            if !microphoneIsActive {
                baselineReady = true
                statusText = "Waiting for microphone"
            }
            return
        }

        if !wasActive && microphoneIsActive {
            beginActionSession()
        } else if wasActive && !microphoneIsActive {
            endActionSession()
        }
    }

    private func handleMediaUpdate(_ snapshot: MediaSnapshot?) {
        currentMedia = snapshot
        guard var session = ownedPause else { return }

        guard let snapshot else {
            return
        }

        if snapshot.identity != session.identity {
            session.invalidated = true
            statusText = "Media changed; not restoring"
        } else if !snapshot.isPlaying {
            session.pauseConfirmed = true
        } else if session.pauseConfirmed {
            session.invalidated = true
            statusText = "Playback resumed manually; not intervening"
        }

        ownedPause = session
    }

    private func beginActionSession() {
        switch actionMode {
        case .pause:
            beginPauseSession()
        case .duck:
            beginDuckSession()
        }
    }

    private func endActionSession() {
        let hadSession = ownedPause != nil || ownedDuck != nil
        if let session = ownedPause {
            ownedPause = nil
            restoreIfSafe(session, reason: "microphone released", allowWhileMicrophoneActive: false)
        }
        if let session = ownedDuck {
            ownedDuck = nil
            restoreDuckIfSafe(session)
        }
        if !hadSession {
            statusText = "Waiting for microphone"
        }
    }

    private func beginPauseSession() {
        guard isEnabled, ownedPause == nil else { return }
        statusText = "Checking current media"

        Task { [weak self] in
            guard let self else { return }
            let snapshot = await mediaClient.snapshot()
            guard microphoneIsActive, isEnabled, actionMode == .pause else { return }
            currentMedia = snapshot

            guard let snapshot, snapshot.isPlaying else {
                statusText = snapshot == nil ? "No media to pause" : "Media was already paused"
                return
            }

            let succeeded = await mediaClient.send(.pause)
            guard microphoneIsActive, isEnabled, actionMode == .pause else {
                if succeeded {
                    _ = await mediaClient.send(.play)
                }
                return
            }

            guard succeeded else {
                mediaStatus = "Failed to pause media"
                statusText = "Media was not paused"
                return
            }

            ownedPause = OwnedPause(
                identity: snapshot.identity,
                applicationName: snapshot.applicationName,
                title: snapshot.title
            )
            statusText = "Paused \(snapshot.applicationName)"
            logger.info("Paused media: \(snapshot.applicationName, privacy: .public) / \(snapshot.title, privacy: .public)")
        }
    }

    private func beginDuckSession() {
        guard isEnabled, ownedDuck == nil else { return }
        statusText = "Checking system volume"

        let preview = previewDuck
        endVolumePreview(restore: false)

        let snapshot: SystemVolumeSnapshot
        if let preview,
           DuckPolicy.shouldRestore(
            currentVolume: volumeController.snapshot()?.volume,
            duckedTo: preview.duckedTo,
            invalidated: false
           ) {
            snapshot = preview.original
        } else if let current = volumeController.snapshot() {
            snapshot = current
        } else {
            statusText = "Could not read system volume"
            return
        }
        guard microphoneIsActive, isEnabled, actionMode == .duck else { return }

        let target = DuckPolicy.appliedTarget(
            originalVolume: snapshot.volume,
            requestedTarget: Float(duckVolume)
        )
        guard DuckPolicy.shouldBeginDuck(
            currentVolume: snapshot.volume,
            isMuted: snapshot.isMuted,
            targetVolume: target
        ) else {
            statusText = snapshot.isMuted
                ? "Output is muted; leaving volume unchanged"
                : "Volume already at or below duck level"
            return
        }

        guard volumeController.setVolume(target) else {
            statusText = "Could not lower volume"
            return
        }

        ownedDuck = OwnedDuck(original: snapshot, duckedTo: target)
        statusText = "Volume lowered to \(percentString(target))"
        logger.info("Lowered system volume to \(self.percentString(target), privacy: .public)")
    }

    private func restoreIfSafe(_ session: OwnedPause, reason: String, allowWhileMicrophoneActive: Bool) {
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await mediaClient.snapshot()
            currentMedia = snapshot

            guard PausePolicy.shouldRestore(
                sessionIdentity: session.identity,
                currentMedia: snapshot,
                invalidated: session.invalidated,
                microphoneIsActive: microphoneIsActive,
                allowWhileMicrophoneActive: allowWhileMicrophoneActive
            ) else {
                statusText = "Keeping current media state"
                return
            }

            let succeeded = await mediaClient.send(.play)
            statusText = succeeded ? "Resumed \(session.applicationName)" : "Failed to resume media"
            logger.info("Resumed media (\(reason, privacy: .public)): \(session.applicationName, privacy: .public)")
        }
    }

    private func restoreDuckIfSafe(_ session: OwnedDuck) {
        let current = volumeController.snapshot()
        guard DuckPolicy.shouldRestore(
            currentVolume: current?.volume,
            duckedTo: session.duckedTo,
            invalidated: session.invalidated
        ) else {
            statusText = "Keeping current volume"
            return
        }

        let succeeded = volumeController.setVolume(session.original.volume)
        if session.original.isMuted {
            _ = volumeController.setMuted(true)
        }
        statusText = succeeded ? "Volume restored" : "Failed to restore volume"
        if succeeded {
            logger.info("Restored system volume")
        }
    }

    private func schedulePreviewAfterSliderSettles() {
        previewDebounceTask?.cancel()
        guard !isSliderEditing, ownedDuck == nil else { return }
        previewDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: previewIdleDelayNanoseconds)
            guard !Task.isCancelled, !isSliderEditing else { return }
            startVolumePreview()
        }
    }

    private func startVolumePreview() {
        guard isEnabled, actionMode == .duck, ownedDuck == nil else { return }

        let original: SystemVolumeSnapshot
        if let previewDuck {
            original = previewDuck.original
        } else if let snapshot = volumeController.snapshot() {
            original = snapshot
        } else {
            return
        }

        let target = DuckPolicy.appliedTarget(
            originalVolume: original.volume,
            requestedTarget: Float(duckVolume)
        )
        guard DuckPolicy.shouldBeginDuck(
            currentVolume: original.volume,
            isMuted: original.isMuted,
            targetVolume: target
        ) else {
            endVolumePreview(restore: true)
            return
        }

        guard volumeController.setVolume(target) else { return }
        previewDuck = OwnedDuck(original: original, duckedTo: target)
        statusText = "Previewing duck to \(percentString(target))"
        schedulePreviewRestore()
    }

    private func schedulePreviewRestore() {
        previewRestoreTask?.cancel()
        previewRestoreTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: previewHoldNanoseconds)
            guard !Task.isCancelled else { return }
            endVolumePreview(restore: true)
        }
    }

    private func endVolumePreview(restore: Bool) {
        previewDebounceTask?.cancel()
        previewDebounceTask = nil
        previewRestoreTask?.cancel()
        previewRestoreTask = nil
        guard let session = previewDuck else { return }
        previewDuck = nil
        guard restore else { return }
        restoreDuckIfSafe(session)
    }

    private func percentString(_ volume: Float) -> String {
        "\(Int((volume * 100).rounded()))%"
    }
}
