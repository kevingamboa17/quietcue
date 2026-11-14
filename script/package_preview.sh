#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MicPause"
DISPLAY_NAME="QuietCue"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/dist/$APP_NAME.app"
PREVIEW_ROOT="$ROOT_DIR/dist/$DISPLAY_NAME-Preview"
STAGE_DIR="$PREVIEW_ROOT/stage"
APP_DEST="$STAGE_DIR/$DISPLAY_NAME.app"
DMG_PATH="$ROOT_DIR/dist/$DISPLAY_NAME-Preview.dmg"

"$ROOT_DIR/script/build_and_run.sh" --verify

rm -rf "$PREVIEW_ROOT" "$DMG_PATH"
mkdir -p "$STAGE_DIR"
cp -R "$APP_SOURCE" "$APP_DEST"
ln -s /Applications "$STAGE_DIR/Applications"

# Re-sign the staged bundle after copying all resources. This is an ad hoc
# signature for private testing only, not a Developer ID distribution signature.
codesign --force --deep --sign - "$APP_DEST"
codesign --verify --deep --strict "$APP_DEST"

hdiutil create \
  -volname "$DISPLAY_NAME Preview" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$PREVIEW_ROOT"
echo "Preview DMG created: $DMG_PATH"
