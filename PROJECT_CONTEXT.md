# QuietCue — Project Context

## Product

QuietCue is a macOS menu bar utility that reacts when the microphone is in use. It can pause the current Now Playing session or lower system output volume to a user-chosen level, then restore only if QuietCue still owns the change.

## Stack

- Swift 6 / SwiftUI menu bar app (`Sources/MicPause/`)
- MediaRemote adapter (Perl + bundled framework) for Now Playing control
- CoreAudio (`AudioHardwareSystem` on macOS 15+) for microphone process detection and system volume

## Key flows

1. **Microphone monitor** polls `isRunningInput` on audio processes (~250 ms). `MicrophoneInUsePolicy` drops detections when only the Now Playing app is reported (playback false positive).
2. **Action mode**: `pause` (MediaRemote pause/play) or `duck` (system volume via `SystemVolumeController`).
3. **Duck preview**: slider adjusts stored duck level; a short preview lowers volume temporarily for user feedback.

## Conventions

- User defaults keys prefixed with `MicPause.`
- Default duck level: 20% (`MicActionMode.persistedDuckVolume`)
- Duck/restore policy lives in `DuckPolicy` with a small volume tolerance.