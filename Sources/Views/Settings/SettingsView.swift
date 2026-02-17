import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newExcludedApp: String = ""
    @State private var showClearDataConfirmation: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MPTheme.Spacing.xl) {

                // MARK: - Header
                Text("Settings")
                    .font(MPTheme.Typography.display(32))
                    .foregroundColor(MPTheme.Colors.textPrimary)
                    .padding(.bottom, MPTheme.Spacing.sm)

                // MARK: - Capture Settings
                SettingsSection(title: "CAPTURE") {
                    VStack(spacing: MPTheme.Spacing.lg) {
                        // Capture enabled toggle
                        SettingsToggleRow(
                            label: "Screen Capture",
                            description: "Record on-screen activity for summarization",
                            icon: "camera.fill",
                            isOn: settingsBinding.captureEnabled
                        )

                        Divider().background(MPTheme.Colors.border)

                        // Capture interval
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                    Text("Capture Interval")
                                        .font(MPTheme.Typography.body(13))
                                        .foregroundColor(MPTheme.Colors.textPrimary)
                                    Text("How often to capture screen content")
                                        .font(MPTheme.Typography.caption(11))
                                        .foregroundColor(MPTheme.Colors.textTertiary)
                                }
                                Spacer()
                                Text("\(appState.settings.captureIntervalSeconds)s")
                                    .font(MPTheme.Typography.monoBold(14))
                                    .foregroundColor(MPTheme.Colors.accent)
                                    .frame(width: 44, alignment: .trailing)
                            }

                            // Custom slider
                            IntervalSlider(value: settingsBinding.captureIntervalSeconds)
                        }

                        Divider().background(MPTheme.Colors.border)

                        // OCR toggle
                        SettingsToggleRow(
                            label: "On-Device OCR",
                            description: "Extract text from screen captures using Vision framework",
                            icon: "text.viewfinder",
                            isOn: settingsBinding.ocrEnabled
                        )

                        Divider().background(MPTheme.Colors.border)

                        // Launch at login
                        SettingsToggleRow(
                            label: "Launch at Login",
                            description: "Start Eval automatically when you log in",
                            icon: "power",
                            isOn: settingsBinding.launchAtLogin
                        )
                    }
                }

                // MARK: - Excluded Apps
                SettingsSection(title: "EXCLUDED APPLICATIONS") {
                    VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                        Text("These applications will not be captured or analyzed")
                            .font(MPTheme.Typography.caption(11))
                            .foregroundColor(MPTheme.Colors.textTertiary)

                        // Excluded apps list
                        ForEach(appState.settings.excludedApps, id: \.self) { app in
                            HStack(spacing: MPTheme.Spacing.md) {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(MPTheme.Colors.textTertiary)

                                Text(app)
                                    .font(MPTheme.Typography.body(12))
                                    .foregroundColor(MPTheme.Colors.textSecondary)

                                Spacer()

                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.settings.excludedApps.removeAll { $0 == app }
                                        appState.applySettings()
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(MPTheme.Colors.textTertiary)
                                        .padding(4)
                                        .background(MPTheme.Colors.bgSecondary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, MPTheme.Spacing.xs)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Excluded app: \(app)")
                            .accessibilityHint("Contains remove button")
                        }

                        // Add new exclusion
                        HStack(spacing: MPTheme.Spacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(MPTheme.Colors.accent)

                            TextField("Add application name...", text: $newExcludedApp, onCommit: {
                                if !newExcludedApp.isEmpty {
                                    withAnimation {
                                        appState.settings.excludedApps.append(newExcludedApp)
                                        appState.applySettings()
                                        newExcludedApp = ""
                                    }
                                }
                            })
                            .textFieldStyle(.plain)
                            .font(MPTheme.Typography.body(12))
                            .foregroundColor(MPTheme.Colors.textPrimary)
                        }
                        .padding(.top, MPTheme.Spacing.xs)
                    }
                }

                // MARK: - Storage
                SettingsSection(title: "STORAGE") {
                    VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                        // Storage location
                        HStack {
                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("Data Location")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text(appState.settings.storageLocation)
                                    .font(MPTheme.Typography.mono(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }
                            Spacer()
                            Button("Change") {}
                                .buttonStyle(MPSecondaryButtonStyle())
                        }

                        Divider().background(MPTheme.Colors.border)

                        // Storage usage
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                            HStack {
                                Text("Storage Used")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f GB / %.1f GB", appState.settings.currentStorageGB, appState.settings.storageLimitGB))
                                    .font(MPTheme.Typography.mono(12))
                                    .foregroundColor(MPTheme.Colors.textSecondary)
                            }

                            // Storage bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(MPTheme.Colors.bgSecondary)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [MPTheme.Colors.accent, MPTheme.Colors.accent.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * (appState.settings.currentStorageGB / appState.settings.storageLimitGB))
                                }
                            }
                            .frame(height: 6)
                        }

                        Divider().background(MPTheme.Colors.border)

                        // Storage limit
                        HStack {
                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("Storage Limit")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text("Oldest data is purged when limit is reached")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }
                            Spacer()
                            Text(String(format: "%.0f GB", appState.settings.storageLimitGB))
                                .font(MPTheme.Typography.monoBold(14))
                                .foregroundColor(MPTheme.Colors.accent)
                        }
                    }
                }

                // MARK: - AI Model
                SettingsSection(title: "AI MODEL") {
                    VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                        HStack(spacing: MPTheme.Spacing.lg) {
                            // Model icon
                            ZStack {
                                RoundedRectangle(cornerRadius: MPTheme.Radius.md)
                                    .fill(MPTheme.Colors.accentSubtle)
                                    .frame(width: 48, height: 48)

                                Image(systemName: "brain")
                                    .font(.system(size: 22))
                                    .foregroundColor(MPTheme.Colors.accent)
                            }

                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text(appState.summarizer.backendName)
                                    .font(MPTheme.Typography.heading(15))
                                    .foregroundColor(MPTheme.Colors.textPrimary)

                                Text("Local summarization engine")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }

                            Spacer()

                            // Status badge
                            AIStatusBadge(status: appState.summarizer.isReady ? .ready : .notInstalled)
                        }

                        Divider().background(MPTheme.Colors.border)

                        HStack {
                            Text("All processing happens on-device. No data leaves your Mac.")
                                .font(MPTheme.Typography.caption(11))
                                .foregroundColor(MPTheme.Colors.textTertiary)

                            Spacer()

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 14))
                                .foregroundColor(MPTheme.Colors.success.opacity(0.7))
                        }
                    }
                }

                // MARK: - Permissions
                SettingsSection(title: "PERMISSIONS") {
                    VStack(spacing: MPTheme.Spacing.lg) {
                        // Screen Recording
                        HStack(spacing: MPTheme.Spacing.md) {
                            Image(systemName: "camera.metering.spot")
                                .font(.system(size: 14))
                                .foregroundColor(appState.permissionManager.screenRecordingGranted ? MPTheme.Colors.success : MPTheme.Colors.error)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("Screen Recording")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text("Required to capture on-screen content")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }

                            Spacer()

                            if appState.permissionManager.screenRecordingGranted {
                                Text("Granted")
                                    .font(MPTheme.Typography.mono(10))
                                    .foregroundColor(MPTheme.Colors.success)
                            } else {
                                Button("Grant Access") {
                                    appState.permissionManager.requestScreenRecordingPermission()
                                }
                                .buttonStyle(MPAccentButtonStyle())
                            }
                        }

                        Divider().background(MPTheme.Colors.border)

                        // Accessibility
                        HStack(spacing: MPTheme.Spacing.md) {
                            Image(systemName: "accessibility")
                                .font(.system(size: 14))
                                .foregroundColor(appState.permissionManager.accessibilityGranted ? MPTheme.Colors.success : MPTheme.Colors.warning)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("Accessibility")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text("Optional — enables browser URL extraction")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }

                            Spacer()

                            if appState.permissionManager.accessibilityGranted {
                                Text("Granted")
                                    .font(MPTheme.Typography.mono(10))
                                    .foregroundColor(MPTheme.Colors.success)
                            } else {
                                Button("Grant Access") {
                                    appState.permissionManager.requestAccessibilityPermission()
                                }
                                .buttonStyle(MPAccentButtonStyle())
                            }
                        }

                        Text("macOS keeps these permissions even if you uninstall the app. You can remove them in System Settings > Privacy & Security.")
                            .font(MPTheme.Typography.caption(11))
                            .foregroundColor(MPTheme.Colors.textTertiary)
                    }
                }

                // MARK: - Privacy & Data (M7)
                SettingsSection(title: "PRIVACY & DATA") {
                    VStack(alignment: .leading, spacing: MPTheme.Spacing.lg) {
                        // FileVault status
                        HStack(spacing: MPTheme.Spacing.md) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 14))
                                .foregroundColor(appState.fileVaultEnabled ? MPTheme.Colors.success : MPTheme.Colors.warning)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("FileVault Disk Encryption")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text(appState.fileVaultEnabled
                                     ? "Your disk is encrypted. All Eval data is protected at rest."
                                     : "FileVault is not enabled. Consider enabling it in System Settings for full-disk encryption.")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }

                            Spacer()

                            Text(appState.fileVaultEnabled ? "Enabled" : "Disabled")
                                .font(MPTheme.Typography.mono(10))
                                .foregroundColor(appState.fileVaultEnabled ? MPTheme.Colors.success : MPTheme.Colors.warning)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("FileVault disk encryption: \(appState.fileVaultEnabled ? "Enabled" : "Disabled")")

                        Divider().background(MPTheme.Colors.border)

                        // App-level encryption toggle
                        SettingsToggleRow(
                            label: "App-Level Encryption",
                            description: "Encrypt capture files with AES-256-GCM (recommended if FileVault is disabled)",
                            icon: "lock.fill",
                            isOn: settingsBinding.encryptionEnabled
                        )

                        Divider().background(MPTheme.Colors.border)

                        SettingsToggleRow(
                            label: "Delete Screenshots After Summarization",
                            description: "Remove screenshot PNGs after activity summaries are generated",
                            icon: "photo.on.rectangle.angled",
                            isOn: settingsBinding.deleteScreenshotsAfterSummarize
                        )

                        Divider().background(MPTheme.Colors.border)

                        // No network access badge
                        HStack(spacing: MPTheme.Spacing.md) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 14))
                                .foregroundColor(MPTheme.Colors.success)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                Text("Zero Network Access")
                                    .font(MPTheme.Typography.body(13))
                                    .foregroundColor(MPTheme.Colors.textPrimary)
                                Text("Eval has no internet permissions. No data ever leaves your Mac. No analytics, no telemetry.")
                                    .font(MPTheme.Typography.caption(11))
                                    .foregroundColor(MPTheme.Colors.textTertiary)
                            }

                            Spacer()

                            Text("Verified")
                                .font(MPTheme.Typography.mono(10))
                                .foregroundColor(MPTheme.Colors.success)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Zero network access: Verified. No data ever leaves your Mac.")

                        Divider().background(MPTheme.Colors.border)

                        // Clear all data
                        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
                            HStack(spacing: MPTheme.Spacing.md) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(MPTheme.Colors.error)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                                    Text("Clear All Data")
                                        .font(MPTheme.Typography.body(13))
                                        .foregroundColor(MPTheme.Colors.textPrimary)
                                    Text("Permanently delete all captures, summaries, and activity history")
                                        .font(MPTheme.Typography.caption(11))
                                        .foregroundColor(MPTheme.Colors.textTertiary)
                                }

                                Spacer()

                                Button(action: {
                                    showClearDataConfirmation = true
                                }) {
                                    if appState.isClearingData {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 80)
                                    } else {
                                        Text("Clear Data")
                                            .font(MPTheme.Typography.caption(11))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, MPTheme.Spacing.md)
                                            .padding(.vertical, MPTheme.Spacing.sm)
                                            .background(MPTheme.Colors.error)
                                            .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.isClearingData)
                                .accessibilityLabel("Clear all data")
                                .accessibilityHint("Permanently deletes all captures, summaries, and history")
                            }
                        }
                        .alert("Clear All Data?", isPresented: $showClearDataConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Delete Everything", role: .destructive) {
                                appState.clearAllData()
                            }
                        } message: {
                            Text("This will permanently delete all captures, screenshots, activity summaries, and history. This action cannot be undone.")
                        }
                    }
                }

                // MARK: - About
                VStack(alignment: .center, spacing: MPTheme.Spacing.sm) {
                    Text("Eval v0.1.0")
                        .font(MPTheme.Typography.mono(11))
                        .foregroundColor(MPTheme.Colors.textTertiary)
                    Text("Privacy-focused activity recorder")
                        .font(MPTheme.Typography.caption(10))
                        .foregroundColor(MPTheme.Colors.textTertiary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, MPTheme.Spacing.lg)
            }
            .padding(MPTheme.Spacing.xxl)
        }
        .background(MPTheme.Colors.bgPrimary)
    }

    // MARK: - Binding Helper

    /// Binding that syncs changes back to AppState and applies to the scheduler.
    private var settingsBinding: Binding<AppSettings> {
        Binding(
            get: { appState.settings },
            set: { newValue in
                appState.settings = newValue
                appState.applySettings()
            }
        )
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MPTheme.Spacing.md) {
            Text(title)
                .sectionLabel()

            content
                .cardStyle()
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let label: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isOn ? MPTheme.Colors.accent : MPTheme.Colors.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: MPTheme.Spacing.xs) {
                Text(label)
                    .font(MPTheme.Typography.body(13))
                    .foregroundColor(MPTheme.Colors.textPrimary)
                Text(description)
                    .font(MPTheme.Typography.caption(11))
                    .foregroundColor(MPTheme.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(MPTheme.Colors.accent)
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(description)")
        .accessibilityValue(isOn ? "Enabled" : "Disabled")
        .accessibilityHint("Double-click to toggle")
    }
}

// MARK: - Interval Slider

struct IntervalSlider: View {
    @Binding var value: Int
    private let steps = [5, 10, 15, 30, 60, 120]

    private var sliderValue: Double {
        Double(steps.firstIndex(of: value) ?? 3)
    }

    var body: some View {
        HStack(spacing: MPTheme.Spacing.md) {
            ForEach(steps, id: \.self) { step in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        value = step
                    }
                }) {
                    Text(step < 60 ? "\(step)s" : "\(step/60)m")
                        .font(MPTheme.Typography.mono(10))
                        .foregroundColor(value == step ? MPTheme.Colors.accent : MPTheme.Colors.textTertiary)
                        .padding(.horizontal, MPTheme.Spacing.sm)
                        .padding(.vertical, MPTheme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                                .fill(value == step ? MPTheme.Colors.accentMuted : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                                .stroke(value == step ? MPTheme.Colors.accent.opacity(0.3) : MPTheme.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Capture interval \(step < 60 ? "\(step) seconds" : "\(step/60) minutes")\(value == step ? ", selected" : "")")
                .accessibilityAddTraits(value == step ? [.isSelected] : [])
            }
            Spacer()
        }
    }
}

// MARK: - AI Status Badge

struct AIStatusBadge: View {
    let status: AIModelStatus

    private var color: Color {
        switch status {
        case .ready: return MPTheme.Colors.success
        case .downloading: return MPTheme.Colors.warning
        case .notInstalled: return MPTheme.Colors.textTertiary
        case .error: return MPTheme.Colors.error
        }
    }

    var body: some View {
        HStack(spacing: MPTheme.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)

            Text(status.rawValue)
                .font(MPTheme.Typography.mono(11))
                .foregroundColor(color)
        }
        .padding(.horizontal, MPTheme.Spacing.md)
        .padding(.vertical, MPTheme.Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
        .accessibilityLabel("AI model status: \(status.rawValue)")
    }
}

// MARK: - Button Styles

struct MPSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MPTheme.Typography.caption(11))
            .foregroundColor(MPTheme.Colors.textSecondary)
            .padding(.horizontal, MPTheme.Spacing.md)
            .padding(.vertical, MPTheme.Spacing.sm)
            .background(MPTheme.Colors.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: MPTheme.Radius.sm)
                    .stroke(MPTheme.Colors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct MPAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MPTheme.Typography.caption(11))
            .foregroundColor(MPTheme.Colors.textInverse)
            .padding(.horizontal, MPTheme.Spacing.md)
            .padding(.vertical, MPTheme.Spacing.sm)
            .background(MPTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: MPTheme.Radius.sm))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
