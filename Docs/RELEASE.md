# Release Guide (Local + GitHub Actions)

This repository uses Swift Package Manager for building the macOS app bundle.

## Local (Unsigned) Release

```bash
Scripts/release_local.sh
```

Environment variables you can override:

```bash
APP_NAME=MacPulse \
VERSION=1.0.0 \
BUILD_NUMBER=1 \
BUNDLE_ID=com.macpulse.app \
Scripts/release_local.sh
```

Output:
- `dist/MacPulse.app`
- `dist/MacPulse-1.0.0.dmg`

## Optional Signing (Developer ID)

If you have a signing identity available in your keychain:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
Scripts/release_local.sh
```

## GitHub Actions Release

Workflow: `.github/workflows/release.yml`

Trigger from Actions → Release → Run workflow, provide:
- `version` (e.g. 1.0.0)
- `build_number` (e.g. 1)

The workflow builds the app bundle and uploads the DMG artifact.

## Notarization (Manual)

Notarization is intentionally handled manually (requires Apple credentials). See Apple docs.
