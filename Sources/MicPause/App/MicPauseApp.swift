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
            alert.messageText = "让 QuietCue 登录时自动运行吗？"
            alert.informativeText = "QuietCue 需要常驻菜单栏，才能在语音输入开始时暂停当前媒体。"
            alert.addButton(withTitle: "开启")
            alert.addButton(withTitle: "暂不")
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
        MenuBarExtra(
            isInserted: Binding(
                get: { model.menuBarItemVisible },
                set: { model.setMenuBarItemVisible($0) }
            )
        ) {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuSymbol)
                .foregroundStyle(model.isMicrophoneActive ? Color.accentColor : Color.secondary)
        }
        .menuBarExtraStyle(.window)
    }
}
