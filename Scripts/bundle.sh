#!/bin/bash
# Builds Accentuate.app (release, ad-hoc signed) into ./build.
#   Scripts/bundle.sh             build only
#   Scripts/bundle.sh --install   also install to /Applications and relaunch
# Signs with the Developer ID from .env (IDENTITY_DARWIN_CODE) when there is one,
# otherwise ad-hoc. VERSION sets the app version (default 1.0.0).
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/load-env.sh

APP=build/Accentuate.app
ID=com.nbonamy.accentuate
VERSION=${VERSION:-1.0.0}
SIGN_IDENTITY=${IDENTITY_DARWIN_CODE:--}

# SwiftPM stamps binaries with the deployment target as their SDK version, and macOS only
# gives an app the current look (Liquid Glass) when it was built with a current SDK.
SDK_VERSION=$(xcrun --sdk macosx --show-sdk-version)
BUILD=(swift build -c release -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker "$SDK_VERSION")
"${BUILD[@]}"
BIN_DIR=$("${BUILD[@]}" --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Accentuate" "$APP/Contents/MacOS/Accentuate"
cp -R "$BIN_DIR"/Accentuate_AccentuateCore.bundle "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Accentuate</string>
    <key>CFBundleIdentifier</key><string>$ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>Accentuate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDisplayName</key><string>Accentuate</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

if [ "$SIGN_IDENTITY" = "-" ]; then
    # Ad-hoc: pin the identity to the bundle id so the Accessibility permission
    # survives rebuilds.
    SIGN=(codesign --force --sign - --identifier "$ID" -r="designated => identifier \"$ID\"")
else
    SIGN=(codesign --force --sign "$SIGN_IDENTITY" --identifier "$ID" --options runtime --timestamp)
fi
"${SIGN[@]}" "$APP/Contents/Resources/Accentuate_AccentuateCore.bundle"
"${SIGN[@]}" "$APP"

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x Accentuate 2>/dev/null && sleep 1 || true
    rm -rf /Applications/Accentuate.app
    cp -R "$APP" /Applications/Accentuate.app
    open /Applications/Accentuate.app
    echo "Installed /Applications/Accentuate.app"
fi
