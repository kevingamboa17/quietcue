import AppKit
import CoreAudio
import Foundation

final class MicrophoneActivityMonitor {
    private let queue = DispatchQueue(label: "com.local.MicPause.microphone-monitor")
    private var timer: DispatchSourceTimer?
    private var hasDeliveredInitialState = false

    var onUpdate: ((Set<MicrophoneProcess>, Bool) -> Void)?

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(250), leeway: .milliseconds(75))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        let activeProcesses = readActiveProcesses()
        let isInitial = !hasDeliveredInitialState
        hasDeliveredInitialState = true

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(activeProcesses, isInitial)
        }
    }

    private func readActiveProcesses() -> Set<MicrophoneProcess> {
        guard #available(macOS 15.0, *) else { return [] }

        do {
            let processes = try AudioHardwareSystem.shared.processes
            return Set(processes.compactMap { process in
                guard (try? process.isRunningInput) == true,
                      let pid = try? process.pid else {
                    return nil
                }

                let bundleIdentifier = try? process.bundleID
                let name = NSRunningApplication(processIdentifier: pid)?.localizedName
                    ?? bundleIdentifier
                    ?? "未知应用"
                return MicrophoneProcess(
                    pid: pid,
                    bundleIdentifier: bundleIdentifier ?? nil,
                    name: name
                )
            })
        } catch {
            return []
        }
    }
}
