#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/MicPause.app"
INSTALL_APP="/Applications/QuietCue.app"

"$ROOT_DIR/script/build_and_run.sh" --bundle

pkill -f "$INSTALL_APP/Contents/MacOS/MicPause" >/dev/null 2>&1 || true
rm -rf "$INSTALL_APP"
cp -R "$SOURCE_APP" "$INSTALL_APP"
/usr/bin/open -n "$INSTALL_APP"

echo "Installed QuietCue to $INSTALL_APP"
