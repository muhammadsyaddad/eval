# MacPulse — Agent Context

## Purpose

MacPulse is a privacy-focused, open-source macOS app that records and summarizes 24 hours of on-device activity. It captures the active window (screenshot + metadata), extracts text via local OCR (Apple Vision), and generates natural language summaries using a local small language model (SLM). No data ever leaves the user's Mac.

Target audience: general knowledge workers — not just developers. The UI must be approachable and polished enough for non-technical users who want to understand how they spend their screen time.


## Target Platform

- macOS 13+ (Ventura). Must run on both Intel and Apple Silicon.
- Avoid APIs that require macOS 14+ unless guarded with `@available(macOS 14.0, *)`.
- SwiftUI is the primary UI framework. No AppKit unless bridging is unavoidable.
- Swift Package Manager (SPM) is the build system. No Xcode project file.


## Architecture

```
MacPulseApp (@main)
├── Models/          — Data types, enums, app state
├── Theme/           — Design system (colors, typography, spacing, modifiers)
├── Views/
│   ├── ContentView  — NavigationSplitView shell + sidebar
│   ├── Today/       — Summary card, top apps bar, activity timeline
│   ├── History/     — Searchable summaries grouped by month
│   ├── Insights/    — Weekly charts, category breakdown, top apps
│   └── Settings/    — Capture, exclusions, storage, AI model
├── Services/        — Capture, OCR, DataStore, Summarization, MenuBar
└── Database/        — (planned) SQLite via GRDB.swift, migrations, FTS5
```


## Current State (M6 Complete, M7 Next)

**M0 (Done):** UI shell fully built with mock data. All four sidebar tabs render correctly. Design system implemented (`MPTheme` in `Sources/Theme/DesignSystem.swift`).

**M1 (Done — 8/8 items):** The live capture pipeline is wired up. Services built:
- `ScreenCaptureService` — captures active window via `CGWindowListCreateImage`
- `WindowMetadataService` — reads app name, bundle ID, window title, browser URLs via Accessibility API
- `CaptureScheduler` — timer-driven capture loop with start/pause/resume/stop, respects exclusions
- `CaptureStorageService` — saves PNG + JSON metadata to `~/Library/Application Support/MacPulse/Captures/`
- `PermissionManager` — checks/requests Screen Recording and Accessibility permissions
- `AppState` updated with `captureScheduler`, `permissionManager`, settings binding
- `ContentView` updated with `CaptureStatusFooter` for live capture status in sidebar
- `SettingsView` updated with permissions section, bound to real `AppState.settings`

**M2 (Done — 7/7 items):** On-device OCR via Apple Vision framework:
- `OCRService` — protocol + implementation using `VNRecognizeTextRequest`, configurable confidence threshold, recognition level, language hints
- `OCRResult` + `TextObservation` models — structured OCR output with full text, per-region confidence, bounding boxes, detected language, processing time
- Language detection via `NLLanguageRecognizer` (macOS 14+ with `@available` guard)
- OCR runs on `CaptureScheduler`'s background queue (`.utility` QoS)
- OCR toggle wired from `AppState.settings.ocrEnabled` through to scheduler
- OCR results stored alongside captures in JSON metadata (StoredCapture now includes `ocrText` and `ocrConfidence`)
- Benchmarked on Intel: ~0.26s (small), ~0.37s (medium), ~0.28s (large) in Accurate mode; Fast mode ~5x faster at ~0.07s

Unit tests: 52 tests covering scheduler lifecycle, metadata models, storage, OCR models, OCR service config, scheduler-OCR integration, and OCR benchmarks.

**M3 (Done — 8/8 items):** Local Data Store — SQLite via GRDB.swift:
- `DatabaseManager` — SQLite lifecycle via GRDB `DatabasePool`, WAL mode, `DatabaseMigrator` with `v1_initial` migration
- `DatabaseRecords` — 4 GRDB record types: `CaptureRecord`, `ActivityEntryRecord`, `DailySummaryRecord`, `AppUsageRecord`
- `DataStore` — `DataStoreProtocol` + GRDB implementation with full CRUD, aggregations, FTS5 search
- `DataRetentionService` — configurable retention policy + storage limit enforcement
- `ExportService` — JSON + CSV export
- Views wired to live DataStore queries with MockDataStore fallback

**M4 (Done — 10/10 items):** On-Device Summarization (Heuristic-first approach):
- `ActivityClassifier` — rule-based categorizer (bundle ID → app name → window title → OCR keywords)
- `SummarizationService` — `SummarizationServiceProtocol` + `HeuristicSummarizer` with category-specific templates
- `SummarizationPipeline` — orchestrator: fetch captures → classify → summarize → store entries + usage + daily summary
- `CaptureScheduler.onCapture` callback wired to DataStore for automatic capture storage
- Settings view shows real summarizer backend name and status

**M5 (Done — 8/8 items):** Menu Bar Widget & Quick View:
- `MenuBarManager` — service binding to AppState via Combine, tracks icon state + quick stats
- `MenuBarPopoverView` — compact popover with status header, today stats (screen time, activities, productivity, top app), toggle button, navigation links, quit
- `MenuBarExtra` wired as second Scene in `MacPulseApp.swift` with `.window` style
- Menu bar icon states: capturing (waveform.circle.fill), paused (pause.circle), idle (circle.dotted), error (exclamationmark.circle)
- Global keyboard shortcut: Cmd+Shift+C to toggle capture via Commands menu
- Menu bar popover now binds directly to `CaptureScheduler.status` for real-time badge/action sync

Unit tests: 170 total, all passing. Build status: **Clean** — zero errors, zero warnings.

**M6 (Done — 9/9 items):** Search & Polish:
- `SearchResult` + `AppError` models — unified search results, user-facing error types
- FTS5 search wired to UI via `AppState.performSearch()` with 300ms debounce
- `SearchResultsView` — grouped results with highlighted matches, source badges
- `OnboardingView` — 4-page first-launch flow (Welcome, Permissions, Tour, Get Started)
- `EmptyStateView` + `ErrorBannerView` — reusable empty/error states across all tabs
- Accessibility: VoiceOver labels on all interactive elements in all views
- Keyboard navigation: Cmd+1/2/3/4 for sidebar tabs, Cmd+Shift+C for capture toggle
- `PerformanceLogger` — timing utilities (mach_absolute_time), memory monitoring (mach_task_basic_info), configurable buffer, slow-operation detection, report generation
- PerformanceLogger integrated into CaptureScheduler (per-step timing), DataStore (FTS5 queries), SummarizationPipeline (full pipeline + sub-steps)

Unit tests: 245 total (38 PerformanceLogger + 37 search/polish), all passing. Build status: **Clean** — zero errors, zero warnings.

**M7 (Done — 8/8 items):** Privacy, Security & Sandboxing:
- `SecurityService` — `SecurityServiceProtocol` with FileVault detection (`fdesetup status`), AES-256-GCM encrypt/decrypt via CryptoKit, `generateEncryptionKey()`, `deleteAllCaptureFiles()`
- `PermissionManager` rewrite — `@Published accessibilityGranted`, periodic re-check timer (10s), `onPermissionRevoked` callback, `startPeriodicRecheck()`/`stopPeriodicRecheck()`
- `AppState.clearAllData()` — orchestrated purge: stops capture + summarization, deletes DB rows, deletes capture files, vacuums DB, resets all @Published properties
- `DatabaseManager.vacuumDatabase()` — runs `VACUUM` via `barrierWriteWithoutTransaction` (outside transaction)
- `CaptureStorageService.deleteAllCaptures()` — removes entire Captures directory tree, recreates empty dir
- `MacPulse.entitlements` — App Sandbox ON, all network/hardware access disabled
- `Info.plist` — Screen Recording + Accessibility usage descriptions, ATS with local networking disabled
- `SettingsView` PRIVACY & DATA section — FileVault status, app-level encryption toggle, zero network badge, Clear All Data with confirmation dialog
- `PRIVACY.md` — comprehensive privacy policy for App Store and GitHub
- Data audit annotations — `// PRIVACY:` comments on all DB columns with sensitivity ratings
- `AppSettings.encryptionEnabled` — toggle for app-level AES-256-GCM encryption

Unit tests: 291 total (46 new privacy/security tests), all passing. Build status: **Clean** — zero errors, zero warnings.

**Post-M7 Updates (Stability & Distribution):**
- Removed mock-data fallback in UI state; fresh installs now show true empty state until real captures exist
- Added `DaySummary.empty()` and `WeeklyInsight.empty()` for safe empty rendering
- Auto-trigger summarization + data refresh after capture insert (debounced) to keep History/Today/Insights in sync
- Menu bar popover uses live `AppState` capture status for accurate badge and action labels
- Added local release tooling: `Scripts/build_app.sh`, `Scripts/create_dmg.sh`, `Scripts/release_local.sh`
- Added release docs and templates: `Docs/RELEASE.md`, `Docs/INSTALL.md`, `Docs/HOMEBREW_CASK_TEMPLATE.md`
- Added `README.md`, `CHANGELOG.md`, and a GitHub Actions release workflow for DMG artifact

See `MILESTONES.md` for the full roadmap from M0 to v1.0 launch.


## UI Structure

- **Sidebar**: Today, History, Insights, Settings. Shows capture status indicator at bottom.
- **Today**: hero stats (screen time, activity count, productivity %), AI summary card, top apps proportional bar, vertical activity timeline with category-colored dots and hover interactions.
- **History**: search bar with live filtering, summaries grouped by month, expandable day cards showing top apps on click.
- **Insights**: key metric cards (avg daily, productivity, top category), weekly bar chart (Swift Charts on macOS 14+, custom fallback on 13), category breakdown with progress bars, top applications ranked list.
- **Settings**: capture toggle + interval selector (5s–2m), OCR toggle, launch-at-login, excluded apps list (add/remove), storage location + usage bar + limit, AI model card with status badge (Ready/Downloading/Not Installed/Error).
- **Menu Bar**: MenuBarExtra with capture status icon (4 states), quick stats popover (screen time, activities, productivity %, top app), toggle capture, navigation to main window tabs, quit button. Cmd+Shift+C keyboard shortcut.


## Design System

Aesthetic: **Refined Dark Industrial** — precision instrument meets privacy dashboard.

- Background layers: `#0F1114` (void) → `#161920` (surface) → `#1C2028` (card) → `#232830` (hover)
- Accent: warm amber `#E8A84C` with muted/subtle opacity variants
- Text: `#E8ECF4` (primary) → `#8B95A8` (secondary) → `#555F73` (tertiary)
- Category colors: amber, teal, slate, rose, emerald, violet, sky, zinc — all desaturated for dark backgrounds
- Typography: system fonts with `.monospaced` design for timestamps/metrics, `.default` design for body text. Thin weight for display numbers, semibold for headings.
- Cards: `cardStyle()` modifier with background + border + corner radius
- Labels: `sectionLabel()` modifier — uppercase, tracked, tiny, tertiary color


## Data Pipeline (Planned)

```
Timer (N seconds)
  → Capture active window screenshot (CGWindowListCreateImage)
  → Read window metadata (app name, title, bundle ID, URL if browser)
  → OCR text extraction (VNRecognizeTextRequest, background queue)
  → Store: capture + metadata + OCR text → SQLite
  → Every 15-30 min: batch OCR text → SLM summarization → activity entry
  → End of day: aggregate entries → daily summary
```


## Local AI Strategy

The summarization backend is abstracted behind a `SummarizationService` protocol, supporting multiple backends:

1. **llama.cpp** (via Swift binding): broadest hardware support, GGUF model files (~500MB–1GB)
2. **Core ML** (converted model): optimized for Apple Silicon Neural Engine
3. **MLX** (Apple framework): Apple Silicon only, good performance

Model management: download, verify, cache in app support directory. User selects model in Settings. If no model is loaded, fall back to raw OCR text display.


## Data & Privacy

- **Zero network access**: no analytics, no telemetry, no cloud sync. Verified at sandboxing level.
- **Data retention**: user-configurable (raw captures vs. summaries have separate retention periods)
- **Excluded apps**: configurable list — no capture, OCR, or summary for these apps
- **Storage limit**: user-configurable cap, oldest data purged when exceeded
- **Clear all data**: one-click purge from Settings
- **Encryption**: FileVault-aware, optional app-level encryption for at-rest data


## Distribution

v1.0 targets three channels:
1. **GitHub Releases**: signed + notarized DMG
2. **Homebrew**: `brew install --cask macpulse`
3. **Mac App Store**: sandboxed submission

See `MILESTONES.md` for the detailed roadmap (M0–M8).


## Conventions

- All source lives under `Sources/` in the SPM target `MacPulse`.
- Theme constants go in `MPTheme` (never hardcode colors or font sizes in views).
- View modifiers: `.cardStyle()`, `.sectionLabel()`, `.glowAccent()` for consistency.
- Extensions on `TimeInterval` and `Date` for formatted display strings.
- Mock data lives in `MockDataStore` — will be replaced by real `DataStore` in M3.
- Use `@EnvironmentObject var appState: AppState` to access shared state in views.
- Services should be protocols first, concrete implementations second (testability).
- Guard macOS 14+ APIs with `@available` and always provide a macOS 13 fallback.
