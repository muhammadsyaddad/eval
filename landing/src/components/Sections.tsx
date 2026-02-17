"use client";

import { FadeIn, StaggerContainer, StaggerItem } from "./Animations";

/* ─────────────────────────────── NAV ─────────────────────────────── */

export function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 backdrop-blur-xl bg-bg-void/70 border-b border-border">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-accent/10 border border-accent/20 flex items-center justify-center group-hover:bg-accent/20 transition-colors">
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              className="text-accent"
            >
              <path
                d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
                fill="currentColor"
                opacity="0.9"
              />
            </svg>
          </div>
          <span className="font-display font-bold text-lg tracking-tight text-text-primary">
            Eval
          </span>
        </a>

        <div className="hidden md:flex items-center gap-8">
          <a
            href="#features"
            className="text-sm text-text-secondary hover:text-text-primary transition-colors"
          >
            Features
          </a>
          <a
            href="#how-it-works"
            className="text-sm text-text-secondary hover:text-text-primary transition-colors"
          >
            How It Works
          </a>
          <a
            href="#privacy"
            className="text-sm text-text-secondary hover:text-text-primary transition-colors"
          >
            Privacy
          </a>
          <a
            href="#faq"
            className="text-sm text-text-secondary hover:text-text-primary transition-colors"
          >
            FAQ
          </a>
        </div>

        <a
          href="#download"
          className="px-5 py-2 rounded-full bg-accent text-bg-void font-semibold text-sm hover:bg-accent/90 transition-all glow-amber"
        >
          Download
        </a>
      </div>
    </nav>
  );
}

/* ─────────────────────────────── HERO ─────────────────────────────── */

export function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center pt-28 pb-12 overflow-hidden">
      {/* Ambient blobs */}
      <div className="ambient-blob w-[600px] h-[600px] -top-40 -left-40 bg-accent/8 animate-[pulse-glow_6s_ease-in-out_infinite]" />
      <div className="ambient-blob w-[400px] h-[400px] top-1/3 -right-20 bg-accent/5 animate-[pulse-glow_8s_ease-in-out_infinite_1s]" />

      {/* Grid pattern */}
      <div
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage: `
            linear-gradient(var(--text-tertiary) 1px, transparent 1px),
            linear-gradient(90deg, var(--text-tertiary) 1px, transparent 1px)
          `,
          backgroundSize: "60px 60px",
        }}
      />

      <div className="relative z-10 max-w-5xl mx-auto px-6 text-center">
        <FadeIn delay={0.1}>
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-accent/20 bg-accent-muted mb-8">
            <span className="w-2 h-2 rounded-full bg-success animate-pulse" />
            <span className="section-label text-accent !text-[11px]">
              Now available for macOS
            </span>
          </div>
        </FadeIn>

        <FadeIn delay={0.2}>
          <h1 className="font-display font-extrabold text-5xl sm:text-6xl md:text-7xl lg:text-8xl leading-[0.95] tracking-tight mb-6">
            Know how you
            <br />
            <span className="text-accent">spend your</span>
            <br />
            screen time
          </h1>
        </FadeIn>

        <FadeIn delay={0.35}>
          <p className="text-text-secondary text-lg sm:text-xl max-w-xl mx-auto leading-relaxed mb-10">
            Eval quietly watches your screen, summarizes your day, and helps
            you understand your habits.{" "}
            <span className="text-text-primary font-medium">
              Everything stays on your Mac.
            </span>
          </p>
        </FadeIn>

        <FadeIn delay={0.5}>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href="#download"
              className="group px-8 py-3.5 rounded-full bg-accent text-bg-void font-bold text-base hover:bg-accent/90 transition-all glow-amber flex items-center gap-2"
            >
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                className="group-hover:translate-y-0.5 transition-transform"
              >
                <path
                  d="M12 3v12m0 0l-4-4m4 4l4-4M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
              Download for Mac
            </a>
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener"
              className="px-8 py-3.5 rounded-full border border-border bg-bg-card text-text-secondary font-medium text-base hover:text-text-primary hover:border-text-tertiary transition-all"
            >
              View on GitHub
            </a>
          </div>
        </FadeIn>

        <FadeIn delay={0.65}>
          <p className="mt-5 text-text-tertiary text-xs font-mono">
            macOS 13+ &middot; Intel & Apple Silicon &middot; Free & Open Source
          </p>
        </FadeIn>

        {/* App preview mock */}
        <FadeIn delay={0.8} className="mt-16 sm:mt-20">
          <div className="relative mx-auto max-w-4xl">
            {/* Window chrome */}
            <div className="card-surface overflow-hidden shadow-2xl shadow-black/40">
              {/* Title bar */}
              <div className="flex items-center gap-2 px-4 py-3 border-b border-border bg-bg-surface/80">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-[#FF5F57]" />
                  <div className="w-3 h-3 rounded-full bg-[#FEBC2E]" />
                  <div className="w-3 h-3 rounded-full bg-[#28C840]" />
                </div>
                <span className="text-text-tertiary text-xs font-mono ml-3">
                  Eval
                </span>
              </div>

              {/* App content mock */}
              <div className="bg-bg-primary p-6 sm:p-8 min-h-[300px] sm:min-h-[400px]">
                {/* Sidebar + content layout */}
                <div className="flex gap-6 h-full">
                  {/* Sidebar */}
                  <div className="hidden sm:flex flex-col gap-1 w-44 shrink-0">
                    {[
                      { icon: "◉", label: "Today", active: true },
                      { icon: "◷", label: "History", active: false },
                      { icon: "◈", label: "Insights", active: false },
                      { icon: "⚙", label: "Settings", active: false },
                    ].map((item) => (
                      <div
                        key={item.label}
                        className={`flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm ${
                          item.active
                            ? "bg-accent-muted text-accent border border-accent/10"
                            : "text-text-tertiary"
                        }`}
                      >
                        <span className="text-xs">{item.icon}</span>
                        {item.label}
                      </div>
                    ))}
                  </div>

                  {/* Main content */}
                  <div className="flex-1 space-y-5">
                    {/* Stats row */}
                    <div className="grid grid-cols-3 gap-3">
                      {[
                        { label: "SCREEN TIME", value: "6h 42m", delta: "+12%" },
                        { label: "ACTIVITIES", value: "47", delta: "" },
                        { label: "PRODUCTIVITY", value: "78%", delta: "+5%" },
                      ].map((stat) => (
                        <div
                          key={stat.label}
                          className="bg-bg-surface rounded-xl p-3 border border-border"
                        >
                          <p className="text-[9px] sm:text-[10px] font-mono uppercase tracking-wider text-text-tertiary">
                            {stat.label}
                          </p>
                          <p className="text-lg sm:text-2xl font-display font-bold text-text-primary mt-1">
                            {stat.value}
                          </p>
                          {stat.delta && (
                            <p className="text-[10px] font-mono text-success mt-0.5">
                              {stat.delta}
                            </p>
                          )}
                        </div>
                      ))}
                    </div>

                    {/* Summary card */}
                    <div className="bg-bg-surface rounded-xl p-4 border border-border">
                      <p className="text-[10px] font-mono uppercase tracking-wider text-accent mb-2">
                        AI SUMMARY
                      </p>
                      <p className="text-sm text-text-secondary leading-relaxed">
                        You spent most of your morning in VS Code working on the
                        authentication module. After lunch, you switched to Figma
                        for design reviews. Productivity peaked between 9–11 AM.
                      </p>
                    </div>

                    {/* Activity timeline (abbreviated) */}
                    <div className="space-y-2">
                      {[
                        {
                          time: "09:12",
                          app: "VS Code",
                          desc: "Editing auth.ts",
                          color: "bg-accent",
                        },
                        {
                          time: "10:45",
                          app: "Chrome",
                          desc: "Stack Overflow",
                          color: "bg-sky-400",
                        },
                        {
                          time: "11:30",
                          app: "Slack",
                          desc: "#engineering",
                          color: "bg-violet-400",
                        },
                      ].map((item) => (
                        <div
                          key={item.time}
                          className="flex items-center gap-3 py-1.5"
                        >
                          <span className="text-[10px] font-mono text-text-tertiary w-10">
                            {item.time}
                          </span>
                          <div
                            className={`w-2 h-2 rounded-full ${item.color}`}
                          />
                          <span className="text-sm text-text-primary">
                            {item.app}
                          </span>
                          <span className="text-xs text-text-tertiary">
                            {item.desc}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Reflection gradient below the window */}
            <div className="absolute -bottom-20 left-1/2 -translate-x-1/2 w-3/4 h-40 bg-accent/5 rounded-full blur-[80px]" />
          </div>
        </FadeIn>
      </div>
    </section>
  );
}

/* ─────────────────────────── FEATURES ─────────────────────────── */

const features = [
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M15 10l-4 4-2-2"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <rect
          x="3"
          y="3"
          width="18"
          height="18"
          rx="3"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>
    ),
    title: "Automatic Activity Tracking",
    description:
      "Eval captures what app you're using and what you're working on — automatically, in the background. No manual logging needed.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M12 6v6l4 2"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <circle
          cx="12"
          cy="12"
          r="9"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>
    ),
    title: "Daily Summaries",
    description:
      "Get a clear, plain-English summary of your day. See your top apps, focus time, and how productive you were — all at a glance.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7z"
          stroke="currentColor"
          strokeWidth="2"
        />
        <circle
          cx="12"
          cy="12"
          r="3"
          stroke="currentColor"
          strokeWidth="2"
        />
      </svg>
    ),
    title: "Smart Text Recognition",
    description:
      "Built-in OCR reads what's on your screen so summaries are context-aware. It knows you were editing code, not just 'using VS Code'.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    ),
    title: "Weekly Insights",
    description:
      "Charts and trends that show how your screen time changes week over week. Spot patterns, see progress, adjust habits.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <rect
          x="5"
          y="11"
          width="14"
          height="10"
          rx="2"
          stroke="currentColor"
          strokeWidth="2"
        />
        <path
          d="M7 11V7a5 5 0 0110 0v4"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    ),
    title: "100% Private",
    description:
      "Zero network access. No accounts. No cloud. Your data lives on your Mac and nowhere else. Verified at the OS level.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M4 6h16M4 12h16M4 18h10"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
    ),
    title: "Menu Bar Widget",
    description:
      "Quick glance at today's stats from the menu bar. Toggle capture, see your top app, and jump to the full dashboard in one click.",
  },
];

export function Features() {
  return (
    <section id="features" className="relative py-32">
      <div className="max-w-6xl mx-auto px-6">
        <FadeIn className="text-center mb-16">
          <p className="section-label text-accent mb-4">Features</p>
          <h2 className="font-display font-bold text-4xl sm:text-5xl tracking-tight">
            Everything you need.
            <br />
            <span className="text-text-secondary">Nothing you don&apos;t.</span>
          </h2>
        </FadeIn>

        <StaggerContainer className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {features.map((feature) => (
            <StaggerItem key={feature.title}>
              <div className="card-surface p-6 h-full hover:border-accent/15 transition-colors group">
                <div className="w-11 h-11 rounded-xl bg-accent-muted border border-accent/10 flex items-center justify-center text-accent mb-5 group-hover:bg-accent/15 transition-colors">
                  {feature.icon}
                </div>
                <h3 className="font-display font-semibold text-lg text-text-primary mb-2">
                  {feature.title}
                </h3>
                <p className="text-text-secondary text-sm leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}

/* ──────────────────────── HOW IT WORKS ──────────────────────── */

const steps = [
  {
    number: "01",
    title: "Install & Grant Permissions",
    description:
      "Download the app, open it, and allow Screen Recording access. That's the only setup — takes about 30 seconds.",
    visual: "⬇",
  },
  {
    number: "02",
    title: "Eval Works in the Background",
    description:
      "It quietly captures what app you're using every few seconds, reads the text on screen, and saves it locally on your Mac.",
    visual: "◉",
  },
  {
    number: "03",
    title: "Get Your Summary",
    description:
      "Open Eval anytime to see a clear breakdown of your day — top apps, focus time, productivity score, and a written summary.",
    visual: "✦",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="relative py-32">
      {/* Background accent */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-accent/[0.02] to-transparent" />

      <div className="relative max-w-4xl mx-auto px-6">
        <FadeIn className="text-center mb-20">
          <p className="section-label text-accent mb-4">How It Works</p>
          <h2 className="font-display font-bold text-4xl sm:text-5xl tracking-tight">
            Three steps.
            <br />
            <span className="text-text-secondary">Zero effort.</span>
          </h2>
        </FadeIn>

        <div className="relative">
          {/* Vertical line */}
          <div className="absolute left-8 top-0 bottom-0 w-px bg-gradient-to-b from-accent/30 via-accent/10 to-transparent hidden md:block" />

          <StaggerContainer className="space-y-16" staggerDelay={0.2}>
            {steps.map((step) => (
              <StaggerItem key={step.number}>
                <div className="flex gap-8 items-start">
                  {/* Step indicator */}
                  <div className="relative shrink-0 hidden md:flex">
                    <div className="w-16 h-16 rounded-2xl bg-bg-card border border-accent/15 flex items-center justify-center">
                      <span className="font-mono text-accent font-bold text-lg">
                        {step.number}
                      </span>
                    </div>
                    {/* Dot on the line */}
                    <div className="absolute left-[31px] top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-accent glow-amber" />
                  </div>

                  {/* Content */}
                  <div className="flex-1 card-surface p-6 sm:p-8">
                    <div className="flex items-center gap-3 mb-3 md:hidden">
                      <span className="font-mono text-accent font-bold text-sm">
                        {step.number}
                      </span>
                      <div className="h-px flex-1 bg-border" />
                    </div>
                    <h3 className="font-display font-semibold text-xl text-text-primary mb-3">
                      {step.title}
                    </h3>
                    <p className="text-text-secondary text-base leading-relaxed">
                      {step.description}
                    </p>
                  </div>
                </div>
              </StaggerItem>
            ))}
          </StaggerContainer>
        </div>
      </div>
    </section>
  );
}

/* ──────────────────────── PRIVACY ──────────────────────── */

const privacyPoints = [
  {
    icon: "🚫",
    label: "Zero Network Access",
    detail: "The app has no internet permissions. Verified at macOS sandbox level.",
  },
  {
    icon: "💾",
    label: "On-Device Only",
    detail: "All data stays in ~/Library/Application Support. Never uploaded anywhere.",
  },
  {
    icon: "🔐",
    label: "Optional Encryption",
    detail: "Enable AES-256-GCM encryption for an extra layer of protection.",
  },
  {
    icon: "🗑️",
    label: "You Control Your Data",
    detail: "Clear everything with one click. Set auto-delete policies. Export anytime.",
  },
];

export function Privacy() {
  return (
    <section id="privacy" className="relative py-32">
      <div className="max-w-5xl mx-auto px-6">
        <div className="card-surface overflow-hidden relative">
          {/* Background glow */}
          <div className="absolute top-0 right-0 w-80 h-80 bg-accent/5 rounded-full blur-[100px]" />

          <div className="relative p-8 sm:p-12 lg:p-16">
            <FadeIn>
              <p className="section-label text-accent mb-4">
                Privacy & Security
              </p>
              <h2 className="font-display font-bold text-3xl sm:text-4xl tracking-tight mb-4">
                Your data never leaves your Mac.
              </h2>
              <p className="text-text-secondary text-lg max-w-lg mb-12">
                Eval is built on one principle: your screen activity is nobody&apos;s
                business but yours. No accounts, no cloud, no tracking — ever.
              </p>
            </FadeIn>

            <StaggerContainer
              className="grid grid-cols-1 sm:grid-cols-2 gap-6"
              staggerDelay={0.12}
            >
              {privacyPoints.map((point) => (
                <StaggerItem key={point.label}>
                  <div className="flex gap-4 p-4 rounded-xl bg-bg-surface/50 border border-border hover:border-accent/10 transition-colors">
                    <span className="text-2xl shrink-0">{point.icon}</span>
                    <div>
                      <p className="font-semibold text-text-primary text-sm mb-1">
                        {point.label}
                      </p>
                      <p className="text-text-tertiary text-sm leading-relaxed">
                        {point.detail}
                      </p>
                    </div>
                  </div>
                </StaggerItem>
              ))}
            </StaggerContainer>

            {/* Open source callout */}
            <FadeIn delay={0.4}>
              <div className="mt-10 pt-8 border-t border-border flex flex-col sm:flex-row items-start sm:items-center gap-4">
                <div className="flex-1">
                  <p className="text-text-primary font-medium">
                    Fully open source
                  </p>
                  <p className="text-text-tertiary text-sm">
                    Inspect every line of code. Build from source. Trust, but verify.
                  </p>
                </div>
                <a
                  href="https://github.com"
                  target="_blank"
                  rel="noopener"
                  className="px-5 py-2.5 rounded-full border border-border bg-bg-hover text-text-secondary text-sm font-medium hover:text-text-primary hover:border-text-tertiary transition-all shrink-0"
                >
                  View Source →
                </a>
              </div>
            </FadeIn>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ──────────────────────── PREVIEW ──────────────────────── */

export function Preview() {
  return (
    <section className="relative py-32 overflow-hidden">
      <div className="max-w-6xl mx-auto px-6">
        <FadeIn className="text-center mb-16">
          <p className="section-label text-accent mb-4">See It In Action</p>
          <h2 className="font-display font-bold text-4xl sm:text-5xl tracking-tight">
            A dashboard that
            <br />
            <span className="text-text-secondary">respects your time.</span>
          </h2>
        </FadeIn>

        <FadeIn delay={0.2}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {/* Today view */}
            <div className="card-surface p-6 space-y-4">
              <p className="section-label text-accent">Today View</p>
              <div className="flex items-end gap-1 h-32">
                {[40, 65, 80, 55, 90, 70, 45, 85, 60, 75, 50, 95].map(
                  (h, i) => (
                    <div
                      key={i}
                      className="flex-1 rounded-sm bg-accent/20 hover:bg-accent/40 transition-colors"
                      style={{ height: `${h}%` }}
                    />
                  )
                )}
              </div>
              <p className="text-text-secondary text-sm">
                Activity heatmap showing your focus periods throughout the day.
              </p>
            </div>

            {/* Insights view */}
            <div className="card-surface p-6 space-y-4">
              <p className="section-label text-accent">Weekly Insights</p>
              <div className="space-y-3">
                {[
                  { label: "Development", pct: 42, color: "bg-accent" },
                  { label: "Communication", pct: 25, color: "bg-violet-400" },
                  { label: "Browsing", pct: 18, color: "bg-sky-400" },
                  { label: "Design", pct: 15, color: "bg-emerald-400" },
                ].map((cat) => (
                  <div key={cat.label}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className="text-text-secondary">{cat.label}</span>
                      <span className="font-mono text-text-tertiary text-xs">
                        {cat.pct}%
                      </span>
                    </div>
                    <div className="h-2 bg-bg-surface rounded-full overflow-hidden">
                      <div
                        className={`h-full ${cat.color} rounded-full`}
                        style={{ width: `${cat.pct}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Menu bar */}
            <div className="card-surface p-6 space-y-4">
              <p className="section-label text-accent">Menu Bar Widget</p>
              <div className="bg-bg-surface rounded-xl p-4 border border-border">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 rounded bg-accent/20 flex items-center justify-center">
                      <span className="text-accent text-[10px]">◉</span>
                    </div>
                    <span className="text-sm font-medium text-text-primary">
                      Capturing
                    </span>
                  </div>
                  <span className="text-xs font-mono text-success">Active</span>
                </div>
                <div className="grid grid-cols-2 gap-3 text-center">
                  <div className="bg-bg-card rounded-lg p-2">
                    <p className="font-display font-bold text-text-primary">
                      4h 12m
                    </p>
                    <p className="text-[10px] font-mono text-text-tertiary">
                      Screen Time
                    </p>
                  </div>
                  <div className="bg-bg-card rounded-lg p-2">
                    <p className="font-display font-bold text-text-primary">
                      82%
                    </p>
                    <p className="text-[10px] font-mono text-text-tertiary">
                      Productivity
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Settings */}
            <div className="card-surface p-6 space-y-4">
              <p className="section-label text-accent">Easy Configuration</p>
              <div className="space-y-3">
                {[
                  { label: "Capture interval", value: "30s" },
                  { label: "Delete after summary", value: "ON" },
                  { label: "OCR enabled", value: "ON" },
                  { label: "Storage limit", value: "5 GB" },
                ].map((setting) => (
                  <div
                    key={setting.label}
                    className="flex items-center justify-between py-2 border-b border-border last:border-0"
                  >
                    <span className="text-sm text-text-secondary">
                      {setting.label}
                    </span>
                    <span className="text-xs font-mono text-accent">
                      {setting.value}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}

/* ──────────────────────── FAQ ──────────────────────── */

const faqs = [
  {
    q: "Does Eval send any data to the internet?",
    a: "No. Eval has zero network permissions — it physically cannot connect to the internet. This is enforced by the macOS sandbox, not just a promise.",
  },
  {
    q: "How much disk space does it use?",
    a: "It depends on your capture interval. With the default 30-second interval and automatic screenshot cleanup, expect around 50–200 MB per day. You can set a storage limit and auto-delete policy.",
  },
  {
    q: "Does it work on Intel Macs?",
    a: "Yes. Eval runs on macOS 13 (Ventura) and later, on both Intel and Apple Silicon Macs.",
  },
  {
    q: "Can I exclude certain apps?",
    a: "Absolutely. Add any app to the exclusion list in Settings and Eval will skip it entirely — no screenshots, no OCR, no summary.",
  },
  {
    q: "What does the AI summary use? Does it need GPT/OpenAI?",
    a: "No external AI service is used. Summaries are generated on-device using a built-in heuristic engine. A future update will add optional local AI model support (also fully on-device).",
  },
  {
    q: "Is it really free?",
    a: "Yes. Eval is free and open source under a permissive license. You can inspect the code, build from source, and contribute.",
  },
];

export function FAQ() {
  return (
    <section id="faq" className="relative py-32">
      <div className="max-w-3xl mx-auto px-6">
        <FadeIn className="text-center mb-16">
          <p className="section-label text-accent mb-4">FAQ</p>
          <h2 className="font-display font-bold text-4xl sm:text-5xl tracking-tight">
            Questions?
            <br />
            <span className="text-text-secondary">Answers.</span>
          </h2>
        </FadeIn>

        <StaggerContainer className="space-y-4" staggerDelay={0.08}>
          {faqs.map((faq) => (
            <StaggerItem key={faq.q}>
              <details className="card-surface group" open={false}>
                <summary className="cursor-pointer px-6 py-5 flex items-center justify-between list-none">
                  <span className="font-medium text-text-primary text-[15px] pr-4">
                    {faq.q}
                  </span>
                  <span className="text-text-tertiary shrink-0 group-open:rotate-45 transition-transform duration-200 text-xl">
                    +
                  </span>
                </summary>
                <div className="px-6 pb-5 -mt-1">
                  <p className="text-text-secondary text-sm leading-relaxed">
                    {faq.a}
                  </p>
                </div>
              </details>
            </StaggerItem>
          ))}
        </StaggerContainer>
      </div>
    </section>
  );
}

/* ──────────────────────── DOWNLOAD CTA ──────────────────────── */

export function DownloadCTA() {
  return (
    <section id="download" className="relative py-32">
      <div className="max-w-4xl mx-auto px-6">
        <FadeIn>
          <div className="relative card-surface overflow-hidden text-center p-10 sm:p-16">
            {/* Background effects */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-96 h-96 bg-accent/8 rounded-full blur-[100px]" />
            <div className="absolute bottom-0 left-1/4 w-64 h-64 bg-accent/5 rounded-full blur-[80px]" />

            <div className="relative">
              <div className="w-16 h-16 rounded-2xl bg-accent/10 border border-accent/20 flex items-center justify-center mx-auto mb-8">
                <svg
                  width="28"
                  height="28"
                  viewBox="0 0 24 24"
                  fill="none"
                  className="text-accent"
                >
                  <path
                    d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
                    fill="currentColor"
                    opacity="0.9"
                  />
                </svg>
              </div>

              <h2 className="font-display font-bold text-3xl sm:text-5xl tracking-tight mb-4">
                Ready to take control?
              </h2>
              <p className="text-text-secondary text-lg max-w-md mx-auto mb-10">
                Download Eval and start understanding your screen time today.
                Free, private, yours.
              </p>

              <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                <a
                  href="#"
                  className="group px-10 py-4 rounded-full bg-accent text-bg-void font-bold text-lg hover:bg-accent/90 transition-all glow-amber flex items-center gap-3"
                >
                  <svg
                    width="22"
                    height="22"
                    viewBox="0 0 24 24"
                    fill="none"
                    className="group-hover:translate-y-0.5 transition-transform"
                  >
                    <path
                      d="M12 3v12m0 0l-4-4m4 4l4-4M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2"
                      stroke="currentColor"
                      strokeWidth="2.5"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                  Download for macOS
                </a>
              </div>

              <p className="mt-6 text-text-tertiary text-xs font-mono">
                v0.1.0 &middot; macOS 13+ &middot; 12 MB &middot; Intel & Apple
                Silicon
              </p>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}

/* ──────────────────────── FOOTER ──────────────────────── */

export function Footer() {
  return (
    <footer className="border-t border-border py-12">
      <div className="max-w-6xl mx-auto px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 rounded-lg bg-accent/10 border border-accent/20 flex items-center justify-center">
              <svg
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                className="text-accent"
              >
                <path
                  d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"
                  fill="currentColor"
                  opacity="0.9"
                />
              </svg>
            </div>
            <span className="font-display font-bold text-sm text-text-secondary">
              Eval
            </span>
          </div>

          <div className="flex items-center gap-6 text-sm text-text-tertiary">
            <a href="#" className="hover:text-text-secondary transition-colors">
              Privacy Policy
            </a>
            <a
              href="https://github.com"
              target="_blank"
              rel="noopener"
              className="hover:text-text-secondary transition-colors"
            >
              GitHub
            </a>
            <a href="#" className="hover:text-text-secondary transition-colors">
              Changelog
            </a>
          </div>

          <p className="text-text-tertiary text-xs font-mono">
            Built with care. Open source.
          </p>
        </div>
      </div>
    </footer>
  );
}
