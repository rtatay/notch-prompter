#!/usr/bin/env bash
#
# Build NotchPrompter in release mode, wrap the binary in a proper .app bundle,
# ad-hoc code-sign it, and install it to /Applications. Re-running is safe —
# the existing app is replaced.
#
# Usage: ./install.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NotchPrompter"
BUNDLE_ID="com.vibe.notchprompter"
CONFIG="release"
STAGING="${REPO_ROOT}/.build/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

echo "==> Building ${APP_NAME} (${CONFIG})"
swift build -c "${CONFIG}"

BIN="${REPO_ROOT}/.build/${CONFIG}/${APP_NAME}"
if [[ ! -x "${BIN}" ]]; then
    echo "error: built binary not found at ${BIN}" >&2
    exit 1
fi

echo "==> Assembling .app bundle"
rm -rf "${STAGING}"
mkdir -p "${STAGING}/Contents/MacOS"
mkdir -p "${STAGING}/Contents/Resources"
cp "${BIN}" "${STAGING}/Contents/MacOS/${APP_NAME}"

cat > "${STAGING}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code-signing"
codesign --force --sign - "${STAGING}"

echo "==> Installing to ${DEST}"
if [[ -d "${DEST}" ]]; then
    rm -rf "${DEST}"
fi
cp -R "${STAGING}" "${DEST}"

echo "==> Done. Launch with:  open '${DEST}'"
