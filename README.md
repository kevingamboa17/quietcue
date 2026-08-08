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

## Build and run

```sh
./script/build_and_run.sh --verify
```

The build script compiles the bundled MediaRemote adapter, builds the SwiftPM
application, stages a real `.app` bundle, and launches it from the menu bar.

## Release packaging

For a private friend preview, create an unsigned/ad hoc-signed DMG:

```sh
./script/package_preview.sh
```

The resulting `dist/QuietCue-Preview.dmg` is intended for testing only. A
friend may need to right-click the app and choose **Open** on first launch.

The release script creates a Developer ID-signed ZIP. It requires a locally
installed `Developer ID Application` certificate:

```sh
./script/package_release.sh
```

After storing Apple notarization credentials in a keychain profile, set
`NOTARIZE=1` to submit the ZIP, staple the notarization ticket, and validate
the final app:

```sh
NOTARIZE=1 NOTARY_PROFILE=quietcue-notary ./script/package_release.sh
```
