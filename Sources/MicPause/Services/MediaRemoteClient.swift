import AppKit
import Foundation

final class MediaRemoteClient: @unchecked Sendable {
    private let scriptURL: URL?
    private let frameworkURL: URL?
    private let queue = DispatchQueue(label: "com.local.MicPause.media-stream")
    private var streamProcess: Process?
    private var streamPipe: Pipe?
    private var streamBuffer = ""
    private var terminationObserver: NSObjectProtocol?

    var onSnapshot: (@Sendable (MediaSnapshot?) -> Void)?

    init(bundle: Bundle = .main) {
        scriptURL = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl")
        frameworkURL = bundle.url(forResource: "MediaRemoteAdapter", withExtension: "framework")
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopStream()
        }
    }

    var isAvailable: Bool {
        scriptURL != nil && frameworkURL != nil
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        stopStream()
    }

    func startStream() {
        guard streamProcess == nil,
              let scriptURL,
              let frameworkURL else {
            return
        }

        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            scriptURL.path,
            frameworkURL.path,
            "stream",
            "--no-diff",
            "--no-artwork"
        ]
        process.standardOutput = pipe
        process.standardError = Pipe()

        streamProcess = process
        streamPipe = pipe
        streamBuffer = ""

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { [weak self] in
                self?.consume(data)
            }
        }

        process.terminationHandler = { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.streamProcess = nil
                self?.streamPipe = nil
                self?.emit(nil)
            }
        }

        do {
            try process.run()
        } catch {
            streamProcess = nil
            streamPipe = nil
            emit(nil)
        }
    }

    func stopStream() {
        guard let process = streamProcess else { return }
        streamPipe?.fileHandleForReading.readabilityHandler = nil
        process.terminate()
        streamProcess = nil
        streamPipe = nil
    }

    func snapshot() async -> MediaSnapshot? {
        guard let scriptURL, let frameworkURL else { return nil }
        let scriptPath = scriptURL.path
        let frameworkPath = frameworkURL.path

        return await Task.detached(priority: .userInitiated) {
            Self.runAdapter(
                scriptPath: scriptPath,
                frameworkPath: frameworkPath,
                arguments: ["get", "--no-artwork"]
            )
        }.value
    }

    func send(_ command: MediaCommand) async -> Bool {
        guard let scriptURL, let frameworkURL else { return false }
        let scriptPath = scriptURL.path
        let frameworkPath = frameworkURL.path
        let commandID = String(command.rawValue)

        return await Task.detached(priority: .userInitiated) {
            Self.runCommand(
                scriptPath: scriptPath,
                frameworkPath: frameworkPath,
                arguments: ["send", commandID]
            )
        }.value
    }

    private func consume(_ data: Data) {
        streamBuffer += String(decoding: data, as: UTF8.self)

        while let newline = streamBuffer.firstIndex(of: "\n") {
            let line = String(streamBuffer[..<newline])
            streamBuffer.removeSubrange(...newline)
            guard let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData),
                  let root = object as? [String: Any],
                  let payload = root["payload"] as? [String: Any] else {
                continue
            }

            emit(MediaSnapshot.fromAdapterPayload(payload))
        }
    }

    private func emit(_ snapshot: MediaSnapshot?) {
        guard let onSnapshot else { return }
        DispatchQueue.main.async {
            onSnapshot(snapshot)
        }
    }

    private static func runAdapter(
        scriptPath: String,
        frameworkPath: String,
        arguments: [String]
    ) -> MediaSnapshot? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath] + arguments
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any] else {
            return nil
        }
        return MediaSnapshot.fromAdapterPayload(payload)
    }

    private static func runCommand(
        scriptPath: String,
        frameworkPath: String,
        arguments: [String]
    ) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath] + arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
