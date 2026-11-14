import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        promptForLoginItemIfNeeded()
    }

    private func promptForLoginItemIfNeeded() {
        let key = "MicPause.loginPromptShown"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let alert = NSAlert()
            alert.messageText = "Open QuietCue automatically when you log in?"
            alert.informativeText = "QuietCue stays in the menu bar so it can pause or lower media as soon as microphone use starts."
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Not now")
            NSApp.activate(ignoringOtherApps: true)

            if alert.runModal() == .alertFirstButtonReturn {
                try? SMAppService.mainApp.register()
            }
        }
    }
}

@main
struct MicPauseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuSymbol)
                .foregroundStyle(model.isMicrophoneActive ? Color.accentColor : Color.secondary)
        }
        .menuBarExtraStyle(.window)
    }
}
