# Releasing Jira Sprint Tracker

This guide covers signed, notarized builds for GitHub Releases and the Homebrew cask.

## One-time Apple setup

### 1. Developer ID certificate

1. Open [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Create **Developer ID Application** (requires Apple Developer Program)
3. Download and double-click to install in Keychain Access
4. Confirm:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 2. Notary credentials (App Store Connect API key)

1. Create an API key at [Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
2. Download `AuthKey_XXXXXXXXXX.p8` (shown once)
3. Store locally (do **not** commit):

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
```

4. Register a notarytool keychain profile (replace placeholders):

```bash
xcrun notarytool store-credentials "JiraSprintTracker" \
  --key ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
  --key-id "XXXXXXXXXX" \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3. Xcode CLI path

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

### 4. Team ID

Find your Team ID in [Membership details](https://developer.apple.com/account) or Xcode → Signing & Capabilities.

Set it when releasing if needed:

```bash
export DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

## Bump the version

Update `MARKETING_VERSION` (and optionally `CURRENT_PROJECT_VERSION`) for the **jira-tracker-widget** target in Xcode, or edit `project.pbxproj`.

## Build, notarize, zip

```bash
chmod +x scripts/release.sh
./scripts/release.sh
```

Useful env vars:

| Variable | Meaning |
|---|---|
| `VERSION` | Override marketing version (default from Xcode) |
| `DEVELOPMENT_TEAM` | Apple Team ID |
| `NOTARY_PROFILE` | notarytool keychain profile (default `JiraSprintTracker`) |
| `SKIP_NOTARIZE=1` | Build/sign/zip only (not for public distribution) |
| `ALLOW_DEVELOPMENT_SIGN=1` | Package with Apple Development if Developer ID is missing (team-local only) |

## Important: Developer ID required for teammate installs

Homebrew installs for people **outside** your Apple Developer team need a **Developer ID Application** certificate + notarization.

If Keychain only has `Apple Development: …`, create and install Developer ID Application first, then run `./scripts/release.sh` again and replace the GitHub Release asset + cask `sha256`.

On success the script prints the zip path and **sha256**.

## Publish GitHub Release

```bash
VERSION=1.0.0   # match the zip
gh release create "v${VERSION}" \
  "dist/JiraSprintTracker-${VERSION}.zip" \
  --title "v${VERSION}" \
  --notes "Install: brew tap mildminihi/jira-sprint-tracker && brew install --cask jira-sprint-tracker"
```

## Update the Homebrew tap

In repo `homebrew-jira-sprint-tracker`, edit `Casks/jira-sprint-tracker.rb`:

1. Set `version` to the new version
2. Set `sha256` to the value printed by `scripts/release.sh`
3. Commit and push

Teammates then run:

```bash
brew update
brew upgrade --cask jira-sprint-tracker
```

## App Group

Config is stored under App Group:

`group.supanat.wanroj.jira-tracker-widget`

Keep this ID aligned in:

- `jira-tracker-widget/jira-tracker-widget.entitlements`
- `Shared/Constants/AppConstants.swift`
- the cask `zap` stanza
