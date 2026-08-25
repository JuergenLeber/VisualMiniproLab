#!/bin/bash
#
# sign-minipro.sh — re-sign the embedded minipro helper with its own entitlements.
#
# The "Embed minipro" copy phase signs the helper with the app's identity but
# without entitlements. A helper spawned by a sandboxed app needs
# com.apple.security.inherit to run under the app's sandbox, and therefore to
# reach the USB device the app is entitled to; the App Store expects nested
# executables to carry it too. Runs after the helper is embedded and before
# Xcode signs the app bundle around it.

set -euo pipefail

if [ "${CODE_SIGNING_ALLOWED:-YES}" != "YES" ]; then
    echo "note: code signing disabled, leaving minipro unsigned"
    exit 0
fi

HELPER="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/minipro"
ENTITLEMENTS="${SRCROOT}/minipro.entitlements"

if [ ! -f "$HELPER" ]; then
    echo "error: no minipro at $HELPER" >&2
    exit 1
fi

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}"
OPTIONS=()
# Xcode drops both of these for ad-hoc signatures, so match what it does.
if [ "$IDENTITY" != "-" ]; then
    OPTIONS+=(--timestamp)
    if [ "${ENABLE_HARDENED_RUNTIME:-NO}" = "YES" ]; then
        OPTIONS+=(--options runtime)
    fi
fi

codesign --force --sign "$IDENTITY" ${OPTIONS[@]+"${OPTIONS[@]}"} \
    --entitlements "$ENTITLEMENTS" "$HELPER"
echo "note: signed minipro with $(basename "$ENTITLEMENTS") as ${IDENTITY}"
