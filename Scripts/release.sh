#!/bin/bash
# Builds, signs, notarizes and publishes a GitHub release.
#   Scripts/release.sh 1.0.0
# Needs .env (see .env.example) and the gh CLI.
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/load-env.sh

VERSION=${1:?usage: Scripts/release.sh <version>}
: "${IDENTITY_DARWIN_CODE:?missing in .env}" "${APPLE_ID:?missing in .env}" \
  "${APPLE_TEAM_ID:?missing in .env}" "${APPLE_PASSWORD:?missing in .env}"

swift test
VERSION=$VERSION Scripts/bundle.sh

APP=build/Accentuate.app
ZIP=build/Accentuate-$VERSION.zip

ditto -c -k --keepParent "$APP" build/notarize.zip
xcrun notarytool submit build/notarize.zip \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_PASSWORD" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"

rm -f "$ZIP" build/notarize.zip
ditto -c -k --keepParent "$APP" "$ZIP"

gh release create "v$VERSION" "$ZIP" --title "Accentuate $VERSION" --notes-file - <<NOTES
Type French without accents and let them appear on their own.

**Install:** unzip, drag Accentuate to Applications, open it and allow it under System Settings → Privacy & Security → Accessibility.
NOTES
echo "Released v$VERSION"
