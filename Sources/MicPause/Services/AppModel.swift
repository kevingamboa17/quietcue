import AppKit
import Combine
import Foundation
import OSLog
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var microphoneProcesses: [MicrophoneProcess] = []
    @Published private(set) var currentMedia: MediaSnapshot?
    @Published private(set) var statusText = "等待麦克风"
    @Published private(set) var mediaStatus = "正在连接媒体控制"
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var menuBarItemVisible: Bool
    @Published var isEnabled: Bool

    private let logger = Logger(subsystem: "com.local.MicPause", category: "coordinator")
    private let microphoneMonitor = MicrophoneActivityMonitor()
    private let mediaClient = MediaRemoteClient()
    private let menuBarHotKey = GlobalHotKey()

    private var microphoneIsActive = false
    private var baselineReady = false
    private var ownedPause: OwnedPause?

    private struct OwnedPause: Sendable {
        let identity: String
        let applicationName: String
        let title: String
        var pauseConfirmed = false
        var invalidated = false
    }

    init() {
        isEnabled = UserDefaults.standard.object(forKey: "MicPause.enabled") as? Bool ?? true
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        menuBarItemVisible = UserDefaults.standard.object(forKey: "MicPause.menuBarItemVisible") as? Bool ?? true

        menuBarHotKey.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                setMenuBarItemVisible(!menuBarItemVisible)
            }
        }
        menuBarHotKey.register()

        mediaClient.onSnapshot = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.handleMediaUpdate(snapshot)
            }
        }
        microphoneMonitor.onUpdate = { [weak self] processes, isInitial in
            self?.handleMicrophoneUpdate(processes, isInitial: isInitial)
        }

        mediaStatus = mediaClient.isAvailable ? "媒体控制已连接" : "媒体控制不可用"
        mediaClient.startStream()
        microphoneMonitor.start()
    }

    deinit {
        microphoneMonitor.stop()
        mediaClient.stopStream()
    }

    var microphoneSummary: String {
        guard !microphoneProcesses.isEmpty else { return "未检测到" }
        let names = microphoneProcesses.map(\.name)
        if names.count == 1 { return names[0] }
        return "\(names[0]) 等 \(names.count) 个应用"
    }

    var isMicrophoneActive: Bool {
        microphoneIsActive
    }

    var isPauseSessionActive: Bool {
        ownedPause != nil
    }

    var mediaSummary: String {
        guard let currentMedia else { return "未检测到播放媒体" }
        let state = currentMedia.isPlaying ? "播放中" : "已暂停"
        return "\(currentMedia.applicationName) · \(state)"
    }

    var menuSymbol: String {
        if !isEnabled { return "mic.slash" }
        if microphoneIsActive { return "mic.fill" }
        if ownedPause != nil { return "pause.circle.fill" }
        return "mic"
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "MicPause.enabled")

        if !enabled {
            let session = ownedPause
            ownedPause = nil
            baselineReady = false
            statusText = "自动暂停已关闭"
            if let session {
                restoreIfSafe(session, reason: "功能关闭", allowWhileMicrophoneActive: true)
            }
        } else {
            baselineReady = microphoneProcesses.isEmpty
            statusText = baselineReady ? "等待麦克风" : "等待当前麦克风使用结束"
        }
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
            logger.error("登录启动设置失败: \(error.localizedDescription, privacy: .public)")
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    func setMenuBarItemVisible(_ visible: Bool) {
        guard visible != menuBarItemVisible else { return }
        menuBarItemVisible = visible
        UserDefaults.standard.set(visible, forKey: "MicPause.menuBarItemVisible")
        statusText = visible ? "菜单栏图标已显示" : "菜单栏图标已隐藏"
    }

    func quit() {
        let session = ownedPause
        ownedPause = nil
        if let session {
            restoreIfSafe(session, reason: "退出应用", allowWhileMicrophoneActive: true)
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
            statusText = baselineReady ? "等待麦克风" : "等待当前麦克风使用结束"
            return
        }

        guard isEnabled else { return }

        if !baselineReady {
            if !microphoneIsActive {
                baselineReady = true
                statusText = "等待麦克风"
            }
            return
        }

        if !wasActive && microphoneIsActive {
            beginPauseSession()
        } else if wasActive && !microphoneIsActive {
            endPauseSession()
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
            statusText = "媒体已切换，不自动恢复"
        } else if !snapshot.isPlaying {
            session.pauseConfirmed = true
        } else if session.pauseConfirmed {
            session.invalidated = true
            statusText = "检测到人工播放，不自动干预"
        }

        ownedPause = session
    }

    private func beginPauseSession() {
        guard isEnabled, ownedPause == nil else { return }
        statusText = "正在检查当前媒体"

        Task { [weak self] in
            guard let self else { return }
            let snapshot = await mediaClient.snapshot()
            guard microphoneIsActive, isEnabled else { return }
            currentMedia = snapshot

            guard let snapshot, snapshot.isPlaying else {
                statusText = snapshot == nil ? "没有可暂停的媒体" : "媒体原本已暂停"
                return
            }

            let succeeded = await mediaClient.send(.pause)
            guard microphoneIsActive, isEnabled else {
                if succeeded {
                    _ = await mediaClient.send(.play)
                }
                return
            }

            guard succeeded else {
                mediaStatus = "媒体暂停失败"
                statusText = "媒体未暂停"
                return
            }

            ownedPause = OwnedPause(
                identity: snapshot.identity,
                applicationName: snapshot.applicationName,
                title: snapshot.title
            )
            statusText = "已暂停 \(snapshot.applicationName)"
            logger.info("暂停媒体: \(snapshot.applicationName, privacy: .public) / \(snapshot.title, privacy: .public)")
        }
    }

    private func endPauseSession() {
        guard let session = ownedPause else {
            statusText = "等待麦克风"
            return
        }
        ownedPause = nil
        restoreIfSafe(session, reason: "麦克风释放", allowWhileMicrophoneActive: false)
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
                statusText = "保持媒体当前状态"
                return
            }

            let succeeded = await mediaClient.send(.play)
            statusText = succeeded ? "已恢复 \(session.applicationName)" : "媒体恢复失败"
            logger.info("恢复媒体 (\(reason, privacy: .public)): \(session.applicationName, privacy: .public)")
        }
    }
}
