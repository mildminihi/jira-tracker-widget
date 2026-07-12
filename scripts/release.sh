#!/usr/bin/env bash
# Build, Developer ID-sign, notarize, and zip Jira Sprint Tracker for GitHub Releases / Homebrew.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="jira-tracker-widget.xcodeproj"
SCHEME="jira-tracker-widget"
APP_NAME="Jira Sprint Tracker"
DIST_DIR="${ROOT}/dist"
ARCHIVE_PATH="${DIST_DIR}/JiraSprintTracker.xcarchive"
EXPORT_DIR="${DIST_DIR}/export"
VERSION="${VERSION:-}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-JiraSprintTracker}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

die() { echo "error: $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd xcodebuild
need_cmd ditto
need_cmd shasum
need_cmd /usr/bin/xcodebuild

XCODE_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$XCODE_PATH" == *CommandLineTools* ]] || [[ -z "$XCODE_PATH" ]]; then
  if [[ -d /Applications/Xcode.app ]]; then
    echo "tip: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  fi
  die "Full Xcode is required (xcode-select currently: ${XCODE_PATH:-none})"
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}'
  )"
fi
[[ -n "$VERSION" ]] || die "could not resolve MARKETING_VERSION (set VERSION=1.0.0)"

if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID="$(
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/DEVELOPMENT_TEAM/{print $2; exit}'
  )"
fi
[[ -n "$TEAM_ID" ]] || die "set DEVELOPMENT_TEAM to your Apple Team ID"

# Prefer an exact Developer ID identity if present
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  die "No 'Developer ID Application' certificate in Keychain.
Create one at https://developer.apple.com/account/resources/certificates/list
then install it in Keychain Access."
fi

ZIP_NAME="JiraSprintTracker-${VERSION}.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
EXPORT_OPTIONS="${DIST_DIR}/ExportOptions.plist"

mkdir -p "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
EOF

echo "==> Archiving ${SCHEME} (${VERSION}) with team ${TEAM_ID}"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY"

echo "==> Exporting Developer ID app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
[[ -d "$APP_PATH" ]] || die "export did not produce ${APP_NAME}.app (look in ${EXPORT_DIR})"

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
  need_cmd xcrun
  echo "==> Notarizing (profile: ${NOTARY_PROFILE})"
  # Zip for upload
  NOTARY_ZIP="${DIST_DIR}/notarize-${VERSION}.zip"
  rm -f "$NOTARY_ZIP"
  ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling"
  xcrun stapler staple "$APP_PATH"
  rm -f "$NOTARY_ZIP"
else
  echo "==> Skipping notarization (SKIP_NOTARIZE=1)"
fi

echo "==> Creating ${ZIP_NAME}"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo
echo "Release artifact ready:"
echo "  file:   ${ZIP_PATH}"
echo "  sha256: ${SHA}"
echo
echo "Next:"
echo "  gh release create \"v${VERSION}\" \"${ZIP_PATH}\" --title \"v${VERSION}\" --notes \"Menu bar Jira sprint tracker.\""
echo "  Update homebrew-jira-sprint-tracker Casks/jira-sprint-tracker.rb version + sha256"
echo "$SHA" > "${DIST_DIR}/${ZIP_NAME}.sha256"
