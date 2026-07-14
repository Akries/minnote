#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MinNote"
PROJECT_NAME="MinNote.xcodeproj"
SCHEME="MinNote"
CONFIGURATION="Debug"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

cd "$ROOT_DIR"

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    build
}

unregister_build_product() {
  "$LSREGISTER" -u "$APP_BUNDLE" >/dev/null 2>&1 || true
}

open_app() {
  "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 &
}

stop_app
build_app
unregister_build_product

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    open_app
    sleep 1
    PID="$(pgrep -nx "$APP_NAME")"
    exec lldb -p "$PID"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.saic.MinNote\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
