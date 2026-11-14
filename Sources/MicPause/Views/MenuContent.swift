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
                title: "Auto pause",
                isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                )
            ) {
                AutomationGlyph()
            }

            actionModePicker

            if model.actionMode == .duck {
                duckSlider
            }

            settingToggle(
                title: "Launch at login",
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
                Text("Quit")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit QuietCue")
            .accessibilityLabel("Quit QuietCue")
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
                .accessibilityLabel(model.isEnabled ? "Enabled" : "Disabled")
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

    private var actionModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When the microphone is in use")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("When the microphone is in use", selection: Binding(
                get: { model.actionMode },
                set: { model.setActionMode($0) }
            )) {
                ForEach(MicActionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!model.isEnabled)
        }
        .padding(.vertical, 8)
        .opacity(model.isEnabled ? 1 : 0.45)
    }

    private var duckSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Duck to \(model.duckVolumePercent)%")
                    .font(.body)
                Spacer()
            }

            Slider(
                value: Binding(
                    get: { model.duckVolume },
                    set: { model.setDuckVolume($0) }
                ),
                in: 0...1
            ) { editing in
                model.setDuckSliderEditing(editing)
            }
            .accessibilityLabel("Duck volume")
            .accessibilityValue("\(model.duckVolumePercent) percent")
        }
        .padding(.bottom, 8)
        .disabled(!model.isEnabled)
        .opacity(model.isEnabled ? 1 : 0.45)
    }

    @ViewBuilder
    private func settingToggle<Icon: View>(
        title: String,
        isOn: Binding<Bool>,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.body)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(Text(title))
        }
        .frame(maxWidth: .infinity)
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
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 17, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .frame(width: 23, height: 23)
            .accessibilityLabel("Auto pause")
    }
}

private struct StartupGlyph: View {
    var body: some View {
        Image(systemName: "power")
            .font(.system(size: 18, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .frame(width: 23, height: 23)
            .accessibilityLabel("Launch at login")
    }
}
