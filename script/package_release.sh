#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MicPause"
DISPLAY_NAME="QuietCue"
BUNDLE_ID="com.local.MicPause"
MIN_SYSTEM_VERSION="15.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Assets/QuietCue.icns"
ADAPTER_SOURCE="$ROOT_DIR/Vendor/mediaremote-adapter"
ADAPTER_BUILD="$ROOT_DIR/.build/mediaremote-adapter-release"
NOTARY_PROFILE="${NOTARY_PROFILE:-quietcue-notary}"

find_signing_identity() {
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' \
    | head -n 1
}

SIGNING_IDENTITY="${SIGNING_IDENTITY:-$(find_signing_identity)}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  cat >&2 <<'MESSAGE'
No Developer ID Application certificate was found.
Install a certificate in this Mac's keychain with a name like:
  Developer ID Application: Your Name (TEAMID)
Then run this script again.
MESSAGE
  exit 3
fi

if [[ "$SIGNING_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "SIGNING_IDENTITY must be a Developer ID Application certificate." >&2
  exit 3
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cmake -S "$ADAPTER_SOURCE" -B "$ADAPTER_BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$ADAPTER_BUILD" --config Release -j2 >/dev/null
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>QuietCue.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>QuietCue detects microphone activity so it can pause the current media.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cp "$ADAPTER_SOURCE/bin/mediaremote-adapter.pl" "$APP_RESOURCES/mediaremote-adapter.pl"
cp -R "$ADAPTER_BUILD/MediaRemoteAdapter.framework" "$APP_RESOURCES/MediaRemoteAdapter.framework"
cp "$ICON_SOURCE" "$APP_RESOURCES/QuietCue.icns"

codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
  "$APP_RESOURCES/MediaRemoteAdapter.framework"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
  "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ZIP_PATH="$RELEASE_DIR/$DISPLAY_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Signed release package: $ZIP_PATH"
echo "Signing identity: $SIGNING_IDENTITY"
echo "To notarize, configure a keychain profile first: $NOTARY_PROFILE"

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  spctl -a -vv "$APP_BUNDLE"
  echo "Notarization complete: $ZIP_PATH"
fi
