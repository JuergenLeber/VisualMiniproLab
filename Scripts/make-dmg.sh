#!/bin/bash
#
# make-dmg.sh — pack a built Visual Minipro Lab.app into a distributable disk image.
#
# The image holds the app next to a symlink to /Applications, so dragging it
# across installs it. Builds are ad-hoc signed, so whoever opens the app has to
# approve it once - see the release notes the workflow writes.
#
# Usage: Scripts/make-dmg.sh --app <path/to/Visual Minipro Lab.app> \
#                            [--version <version>] [--output-dir <dir>] [--help]
#
# The version defaults to the app's CFBundleShortVersionString and only names
# the resulting file. The output directory defaults to dist/ at the repo root.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

VOLUME_NAME="Visual Minipro Lab"
APP_PATH=""
VERSION=""
OUTPUT_DIR="${PROJECT_ROOT}/dist"

fail() {
    echo "make-dmg: error: $*" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --app)
            [ $# -ge 2 ] || fail "--app needs an argument"
            APP_PATH="$2"
            shift 2
            ;;
        --version)
            [ $# -ge 2 ] || fail "--version needs an argument"
            VERSION="$2"
            shift 2
            ;;
        --output-dir)
            [ $# -ge 2 ] || fail "--output-dir needs an argument"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help | -h)
            sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
            exit 0
            ;;
        *)
            fail "unknown argument '$1'"
            ;;
    esac
done

[ -n "$APP_PATH" ] || fail "--app is required"
[ -d "$APP_PATH" ] || fail "no app bundle at $APP_PATH"

if [ -z "$VERSION" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
        "${APP_PATH}/Contents/Info.plist" 2>/dev/null) \
        || fail "could not read CFBundleShortVersionString from the app"
fi

DMG_PATH="${OUTPUT_DIR}/VisualMiniproLab-${VERSION}.dmg"

STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

# ditto keeps the code signature and the symlinks inside the bundle intact.
ditto "$APP_PATH" "${STAGING_DIR}/$(basename "$APP_PATH")"
ln -s /Applications "${STAGING_DIR}/Applications"

mkdir -p "$OUTPUT_DIR"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -quiet \
    "$DMG_PATH"

echo "make-dmg: wrote ${DMG_PATH}"
