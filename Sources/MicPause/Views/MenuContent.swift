import SwiftUI

struct MenuContent: View {
    @ObservedObject var model: AppModel

    private var microphoneLabel: String {
        model.microphoneProcesses.isEmpty ? "—" : model.microphoneSummary
    }

    private var mediaLabel: String {
        model.currentMedia?.applicationName ?? "—"
    }

    private var mediaSymbol: String {
        guard let media = model.currentMedia else { return "play.circle" }
        return media.isPlaying ? "play.circle.fill" : "pause.circle.fill"
    }

    private var mediaTint: Color {
        guard let media = model.currentMedia else { return .secondary }
        return media.isPlaying ? .green : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.vertical, 12)

            stateFlow

            Divider()
                .padding(.vertical, 12)

            settingToggle(
                title: "自动暂停",
                isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                )
            ) {
                AutomationGlyph()
            }

            settingToggle(
                title: "开机启动",
                isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )
            ) {
                StartupGlyph()
            }

            Divider()
                .padding(.vertical, 12)

            Button {
                model.quit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 23, height: 23, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("退出 QuietCue")
            .accessibilityLabel("退出 QuietCue")
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HeaderGlyph(isActive: model.isMicrophoneActive)

            Text("QuietCue")
                .font(.headline)

            Spacer(minLength: 8)

            Circle()
                .fill(model.isEnabled ? Color.green : Color.secondary)
                .frame(width: 9, height: 9)
                .accessibilityLabel(model.isEnabled ? "已启用" : "已停用")
        }
        .frame(height: 34)
    }

    private var stateFlow: some View {
        HStack(alignment: .center, spacing: 8) {
            StateTile(
                systemImage: model.isMicrophoneActive ? "mic.fill" : "mic",
                label: microphoneLabel,
                tint: model.isMicrophoneActive ? .accentColor : .secondary
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(model.isMicrophoneActive ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            StateTile(
                systemImage: mediaSymbol,
                label: mediaLabel,
                tint: mediaTint
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func settingToggle<Icon: View>(
        title: String,
        isOn: Binding<Bool>,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.body)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 4)
    }
}

private struct HeaderGlyph: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .background(.regularMaterial, in: Circle())
                    .offset(x: 4, y: 4)
            }
            .frame(width: 31, height: 31)
            .accessibilityHidden(true)
    }
}

private struct StateTile: View {
    let systemImage: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(tint)
                .frame(height: 34)

            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct AutomationGlyph: View {
    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "mic.fill")
            Image(systemName: "arrow.right")
            Image(systemName: "pause.fill")
        }
        .font(.system(size: 9, weight: .bold))
        .accessibilityLabel("麦克风触发自动暂停")
    }
}

private struct StartupGlyph: View {
    var body: some View {
        HStack(spacing: -2) {
            Image(systemName: "power")
            Image(systemName: "arrow.up")
        }
        .font(.system(size: 13, weight: .semibold))
        .accessibilityLabel("登录时启动")
    }
}
