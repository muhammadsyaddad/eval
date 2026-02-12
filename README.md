# MacPulse

MacPulse is a privacy-focused macOS app that records and summarizes on-device activity using local OCR and summarization. No data leaves your Mac.

## Features

- Active window capture with on-device OCR (Apple Vision)
- Local summarization pipeline (heuristic-first, SLM backends planned)
- Full-text search across history
- Menu bar quick view
- Zero network access (App Sandbox + ATS enforced)
- Optional app-level encryption (AES-256-GCM)

## Requirements

- macOS 13+ (Ventura)
- Apple Silicon or Intel

## Build & Run (Development)

```bash
swift build
swift run
```

## Permissions

MacPulse needs Screen Recording and Accessibility permissions to capture active windows and read window titles/URLs.

## Local Release (Unsigned)

Create a local app bundle and DMG without notarization:

```bash
Scripts/release_local.sh
```

Artifacts are placed in `dist/`.

## Privacy

See `PRIVACY.md` for detailed data handling.
