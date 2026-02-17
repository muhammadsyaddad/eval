# Eval — Milestones to v1.0 Launch

## M0: Foundation (DONE)
> SwiftUI shell with mock data. Proves the UI direction and project structure.

- [x] Package.swift configured for macOS 13+
- [x] SwiftUI app entry point with NavigationSplitView sidebar
- [x] Design system (dark industrial theme, color palette, typography, view modifiers)
- [x] Mock data models: ActivityEntry, DaySummary, WeeklyInsight, AppSettings
- [x] Today view: summary card, top apps bar, vertical activity timeline
- [x] History view: searchable summaries grouped by month, expandable cards
- [x] Insights view: weekly bar chart (Swift Charts + macOS 13 fallback), category breakdown
- [x] Settings view: capture controls, exclusions, storage, AI model status
- [x] Clean build, zero warnings

---

## M1: Screen Capture & Metadata (DONE)
> Wire up the live capture pipeline. No OCR or AI yet — just raw screenshots and window metadata.

- [x] ScreenCaptureService: periodic screenshot of the active window using CGWindowListCreateImage
- [x] WindowMetadataService: read frontmost app name, window title, bundle ID via NSWorkspace + Accessibility API
- [x] BrowserURLExtractor: read URL bar from Safari/Chrome via Accessibility (best-effort, non-blocking)
- [x] CaptureScheduler: timer-driven capture at user-configured interval (5s–2m)
- [x] Pause/resume capture from sidebar status and menu bar
- [x] Request and handle Screen Recording permission (macOS privacy prompt)
- [x] Store raw captures temporarily in sandboxed app support directory
- [x] Unit tests for metadata extraction and scheduler logic

**Exit criteria**: App captures a screenshot + metadata every N seconds and logs it to disk.

---

## M2: On-Device OCR (DONE)
> Extract text from screenshots using Apple Vision framework.

- [x] OCRService: VNRecognizeTextRequest on captured images, confidence filtering
- [x] Text extraction pipeline: capture → OCR → structured OCR result (text + regions + confidence)
- [x] Language detection hint for multi-language support
- [x] Performance: run OCR on background queue, respect CPU budget
- [x] OCR toggle in Settings (already in UI, wire to service)
- [x] Store OCR results alongside captures in local database
- [x] Benchmark: OCR latency per frame on Intel vs Apple Silicon

**Exit criteria**: Every capture produces extracted text, stored alongside the screenshot.

---

## M3: Local Data Store (DONE)
> Persistent storage layer. Replace mock data with real data.

- [x] Database layer: SQLite via GRDB.swift (no Core Data for portability)
- [x] Schema: captures, activity_entries, daily_summaries, app_usage + FTS5 virtual tables
- [x] DataStore protocol: insert, query by date range, full-text search, aggregations
- [x] Migration system for schema versioning
- [x] Data retention engine: configurable retention policy (raw captures vs. summaries)
- [x] Storage usage calculation and enforcement of storage limit
- [x] Export: JSON and CSV export of summaries and activity data
- [x] Wire Today/History/Insights views to live DataStore queries (replace MockDataStore)
- [x] Unit tests for CRUD, search, retention, and export

**Exit criteria**: All UI views show real captured data. Data persists across launches. Export works.

---

## M4: Local SLM Summarization (DONE)
> AI-powered summarization running entirely on-device. Heuristic-first approach.

- [x] SummarizationService protocol: input OCR text + metadata → output natural language summary
- [x] Backend: HeuristicSummarizer with category-specific templates (swappable via protocol)
- [x] ActivityClassifier: rule-based categorizer (bundle ID → app name → window title → OCR keywords)
- [x] SummarizationPipeline: orchestrator — fetch captures → classify → summarize → store entries + usage + daily summary
- [x] CaptureScheduler.onCapture callback wired to DataStore for automatic capture storage
- [x] Model selection UI in Settings shows real summarizer backend name and status
- [x] Fallback: heuristic summary always available; SLM backends (llama.cpp, Core ML, MLX) planned for future

**Exit criteria**: App generates coherent, useful natural language summaries from OCR text without internet.

---

## M5: Menu Bar Widget & Quick View (DONE)
> Persistent presence in the menu bar. Glanceable status and fast access.

- [x] MenuBarExtra (macOS 13+): status icon in the system menu bar
- [x] Menu bar popover: current capture status, today's summary stats, quick toggle on/off
- [x] Click-through to open main window at the relevant tab
- [x] Menu bar icon states: capturing (waveform.circle.fill), paused (pause.circle), idle (circle.dotted), error (exclamationmark.circle)
- [x] Keyboard shortcut to toggle capture: Cmd+Shift+C via Commands menu
- [x] MenuBarPopoverView with compact today summary (screen time, activities, productivity %, top app)

**Exit criteria**: Users can see capture status and today's summary from the menu bar without opening the main window.

---

## M6: Search & Polish (DONE)
> Full-text search across all history. UI refinements and edge cases.

- [x] Full-text search: FTS5 index on OCR text and AI summaries
- [x] Search results view with highlighted matches and date context
- [x] Search from History view (search bar wired to FTS with 300ms debounce)
- [x] Onboarding flow: 4-page first-launch flow (Welcome, Permissions, Tour, Get Started)
- [x] Empty states: reusable EmptyStateView + ErrorBannerView across all tabs
- [x] Error handling: AppError model with severity levels, error banner overlay
- [x] Keyboard navigation: Cmd+1/2/3/4 for sidebar tabs, Cmd+Shift+C for capture toggle
- [x] Accessibility: VoiceOver labels on all interactive elements in all views
- [x] Performance profiling: PerformanceLogger with mach_absolute_time, memory monitoring, slow-operation detection

**Exit criteria**: App is polished enough for non-technical users. Search works across all history.

---

## M7: Privacy, Security & Sandboxing (DONE)
> Harden for distribution. All data stays local.

- [x] App Sandbox entitlements for Mac App Store (Eval.entitlements with all network/hardware access disabled)
- [x] Screen Recording and Accessibility permission handling (graceful denial, periodic re-check with revocation callback)
- [x] No network access: verified zero outbound connections via entitlements + Info.plist ATS config
- [x] Encrypted at-rest storage option (FileVault detection via fdesetup + AES-256-GCM app-level encryption via CryptoKit)
- [x] Clear all data: one-click purge from Settings with confirmation dialog (DB rows + capture files + VACUUM)
- [x] Privacy policy document (PRIVACY.md — comprehensive policy for App Store and GitHub)
- [x] Audit: PRIVACY annotations on all DB columns/records with sensitivity ratings, data retention documented
- [x] Excluded apps: verified no capture/OCR/summary for excluded apps (exclusion check before screenshot capture)

**New services:** SecurityService (FileVault, AES-GCM encrypt/decrypt), PermissionManager rewrite (@Published, re-check timer, revocation callback), AppState.clearAllData() orchestrated purge, SettingsView PRIVACY & DATA section.

Unit tests: 291 total (46 new privacy/security tests), all passing. Build status: **Clean** — zero errors, zero warnings.

---

## M8: Distribution & Launch
> Package, sign, notarize, and ship.

- [ ] Apple Developer signing: Developer ID certificate for direct distribution
- [ ] Notarization: submit to Apple notary service for Gatekeeper approval
- [x] DMG installer: branded disk image with drag-to-Applications flow
- [x] Homebrew cask template: `Docs/HOMEBREW_CASK_TEMPLATE.md`
- [ ] Mac App Store submission: App Store Connect, screenshots, metadata, review
- [x] GitHub Releases: automated release workflow (build → upload DMG artifact)
- [x] README.md: installation, features, privacy statement
- [x] CHANGELOG.md for v1.0
- [ ] Landing page or GitHub Pages site (optional)
- [ ] Announce: relevant communities, Hacker News, macOS dev forums

**Exit criteria**: v1.0 is available on GitHub Releases, Homebrew, and the Mac App Store.

---

## Timeline Estimate (Solo Developer)

| Milestone | Effort | Cumulative |
|-----------|--------|------------|
| M0 Foundation | Done | Done |
| M1 Screen Capture | 1–2 weeks | 2 weeks |
| M2 OCR | 1 week | 3 weeks |
| M3 Data Store | 1–2 weeks | 5 weeks |
| M4 SLM Summarization | 2–3 weeks | 8 weeks |
| M5 Menu Bar Widget | 1 week | 9 weeks |
| M6 Search & Polish | 1–2 weeks | 11 weeks |
| M7 Privacy & Security | 1 week | 12 weeks |
| M8 Distribution | 1 week | 13 weeks |

**Estimated time to launch: ~13 weeks (3 months) of focused work.**

Milestones are intentionally sequential — each one builds on the previous. M1–M3 form the data pipeline, M4 adds intelligence, M5–M6 polish the experience, M7–M8 ship it.
