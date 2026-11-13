#!/bin/bash
# Builds Accentuate.app (release, ad-hoc signed) into ./build.
#   Scripts/bundle.sh             build only
#   Scripts/bundle.sh --install   also install to /Applications and relaunch
# Set SIGN_IDENTITY to use a real certificate instead of ad-hoc ("-").
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Accentuate.app
ID=com.nbonamy.accentuate
SIGN_IDENTITY=${SIGN_IDENTITY:--}

swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Accentuate" "$APP/Contents/MacOS/Accentuate"
cp -R "$BIN_DIR"/Accentuate_AccentuateCore.bundle "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Accentuate</string>
    <key>CFBundleIdentifier</key><string>$ID</string>
    <key>CFBundleName</key><string>Accentuate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleDisplayName</key><string>Accentuate</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# The designated requirement pins the identity to the bundle id, so the Accessibility
# permission survives rebuilds even with an ad-hoc signature.
codesign --force --sign "$SIGN_IDENTITY" --identifier "$ID" \
    -r="designated => identifier \"$ID\"" "$APP/Contents/Resources/Accentuate_AccentuateCore.bundle"
codesign --force --sign "$SIGN_IDENTITY" --identifier "$ID" \
    -r="designated => identifier \"$ID\"" "$APP"

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x Accentuate 2>/dev/null && sleep 1 || true
    rm -rf /Applications/Accentuate.app
    cp -R "$APP" /Applications/Accentuate.app
    open /Applications/Accentuate.app
    echo "Installed /Applications/Accentuate.app"
fi
