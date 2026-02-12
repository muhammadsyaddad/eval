# MacPulse Privacy Policy

**Last updated:** February 2026

## Overview

MacPulse is a privacy-focused macOS application that records and summarizes your on-screen activity. **All data processing happens entirely on your Mac. No data ever leaves your device.**

## What Data We Collect

MacPulse captures the following data from your active screen at user-configured intervals:

| Data Type | Description | Sensitivity | Retention Default |
|-----------|-------------|-------------|-------------------|
| Screenshots | PNG images of the active window | High | 30 days |
| App Name | Name of the frontmost application | Low | 30 days (captures), 90 days (activity entries) |
| Bundle ID | macOS bundle identifier of the app | Low | 30 days |
| Window Title | Title of the active window | Medium — may contain document names, URLs, email subjects | 30 days |
| Browser URL | URL from Safari/Chrome address bar (if Accessibility access is granted) | High — reveals browsing history | 30 days |
| OCR Text | Text extracted from screenshots using Apple Vision | High — contains whatever was on screen | 30 days |
| Activity Summaries | Natural language descriptions of your activity, generated locally | Medium | 90 days |
| Daily Summaries | Aggregated daily narrative with productivity score | Low | 365 days |
| App Usage | Per-app usage duration and category per day | Low | 365 days |

## Where Data Is Stored

All data is stored locally in:

- **Database:** `~/Library/Application Support/MacPulse/macpulse.db` (SQLite with WAL mode)
- **Screenshots:** `~/Library/Application Support/MacPulse/Captures/<date>/` (PNG + JSON metadata)

No data is stored in iCloud, cloud services, or any remote server.

## Network Access

MacPulse has **zero network access**:

- The App Sandbox entitlement `com.apple.security.network.client` is set to `false`
- App Transport Security is configured to deny all connections, including local networking
- No analytics, telemetry, crash reporting, or update checking code exists in the application
- The only external dependency is [GRDB.swift](https://github.com/groue/GRDB.swift), a local SQLite wrapper with no network capabilities

## Third-Party Dependencies

| Dependency | Purpose | Network Access |
|-----------|---------|----------------|
| GRDB.swift | SQLite database wrapper | None |

No other third-party code, SDKs, or frameworks are used.

## AI/ML Processing

MacPulse performs on-device text summarization using:

1. **Heuristic engine** (default): Rule-based categorization and template-based summaries. No model download required.
2. **Local language model** (planned): Small language models (e.g., Llama 3.2 1B) running via llama.cpp, Core ML, or MLX. Model files are stored locally. No API calls are made.

All AI processing runs on your Mac's CPU/GPU/Neural Engine. No data is sent to any cloud AI service.

## User Controls

### Excluded Applications

You can specify applications that MacPulse will never capture, analyze, or store data about. Default exclusions include: Keychain Access, 1Password, and System Preferences/Settings.

When an excluded app is in the foreground, MacPulse:
- Does NOT capture a screenshot
- Does NOT read window metadata
- Does NOT perform OCR
- Does NOT store any record in the database
- Does NOT include the app in summaries

### Data Retention

Data retention periods are configurable:
- **Raw captures** (screenshots + OCR): Default 30 days
- **Activity entries**: Default 90 days
- **Daily summaries & app usage**: Default 365 days
- **Storage limit**: Default 5 GB, oldest data purged when exceeded

### Clear All Data

You can delete all MacPulse data at any time via Settings > Privacy & Data > Clear All Data. This:
1. Stops all capture and summarization
2. Deletes all database records (captures, activity entries, summaries, app usage)
3. Deletes all screenshot files from disk
4. Runs VACUUM on the database to reclaim disk space
5. Resets the UI to its initial state

This action is irreversible.

### Export

You can export your data in JSON or CSV format before clearing it.

## Encryption

### Full-Disk Encryption (FileVault)

MacPulse detects and displays your FileVault status in Settings. When FileVault is enabled, all MacPulse data is encrypted at rest by the operating system. We strongly recommend enabling FileVault.

### App-Level Encryption

MacPulse offers optional AES-256-GCM encryption for capture files, providing an additional layer of protection independent of FileVault. This can be enabled in Settings > Privacy & Data.

## Permissions

MacPulse requests two macOS permissions:

1. **Screen Recording** (required): Allows capturing the active window screenshot. Without this, MacPulse cannot function.
2. **Accessibility** (optional): Allows reading browser URLs from Safari and Chrome. Without this, MacPulse still works but cannot extract browser URLs.

Both permissions are managed by macOS and can be revoked at any time in System Settings > Privacy & Security.

MacPulse monitors permission status and will:
- Display a clear error if Screen Recording is revoked
- Stop capturing automatically if Screen Recording access is lost
- Gracefully degrade (skip URL extraction) if Accessibility access is denied

## Data Sharing

MacPulse does not share your data with anyone. There are no:
- Analytics or telemetry services
- Crash reporting services
- Advertisement networks
- Data brokers
- Cloud synchronization
- Account systems or user authentication

## Open Source

MacPulse is open-source software. You can inspect the complete source code to verify all privacy claims made in this document.

## Contact

For privacy-related questions or concerns, please file an issue on the MacPulse GitHub repository.
