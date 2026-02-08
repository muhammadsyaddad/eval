# MacPulse - Agent Context

Purpose
- MacPulse is a privacy-focused, open-source macOS app that records and summarizes 24 hours of on-device activity using local OCR and SLMs.


Target Platform
- macOS 13+ (Intel-friendly). Keep compatibility with macOS 13.x.
- Avoid APIs that require macOS 14+ unless guarded.


Current UI Structure
- Navigation: sidebar with Today, History, Insights, Settings.
- Today: summary card + vertical activity timeline.
- History: searchable summaries, grouped by month.
- Insights: weekly analytics with monochrome charts.
- Settings: capture interval, exclusions, storage, AI model status.
