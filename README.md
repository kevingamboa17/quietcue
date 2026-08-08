# QuietCue

QuietCue is a small macOS menu bar utility that pauses the current Now Playing
media while any process is actively using a microphone, then restores it only
when QuietCue still owns the paused session.

## Current scope

- macOS 15 or newer on the current Apple Silicon development Mac
- Any active microphone process triggers the pause behavior
- Spotify, Chrome/YouTube, Apple Music, and other apps reported by Now Playing
- Manual media changes during microphone use take precedence
- No audio is recorded or uploaded
- The menu bar icon can be hidden from the in-app control; press `Control-Option-Command-Q` to show it again

## Build and run

```sh
./script/build_and_run.sh --verify
```

The build script compiles the bundled MediaRemote adapter, builds the SwiftPM
application, stages a real `.app` bundle, and launches it from the menu bar.
