#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MicPause"
BUNDLE_ID="com.local.MicPause"
MIN_SYSTEM_VERSION="15.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Assets/QuietCue.icns"

ADAPTER_SOURCE="$ROOT_DIR/Vendor/mediaremote-adapter"
ADAPTER_BUILD="$ROOT_DIR/.build/mediaremote-adapter"

pkill -f "$ROOT_DIR/dist/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || true
pkill -f "$ROOT_DIR/dist/$APP_NAME.app/Contents/Resources/mediaremote-adapter.pl" >/dev/null 2>&1 || true

cmake -S "$ADAPTER_SOURCE" -B "$ADAPTER_BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$ADAPTER_BUILD" --config Release -j2 >/dev/null

swift build -c debug
BUILD_BINARY="$(swift build -c debug --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>QuietCue</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>QuietCue</string>
  <key>CFBundleIconFile</key>
  <string>QuietCue.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

find "$APP_BUNDLE/Contents/Resources" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp "$ADAPTER_SOURCE/bin/mediaremote-adapter.pl" "$APP_RESOURCES/mediaremote-adapter.pl"
cp -R "$ADAPTER_BUILD/MediaRemoteAdapter.framework" "$APP_RESOURCES/MediaRemoteAdapter.framework"
cp "$ICON_SOURCE" "$APP_RESOURCES/QuietCue.icns"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
