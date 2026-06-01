import Euryale
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsStore = SettingsStore.shared
    private static let thresholdOptions = SettingsStore.highCountNotificationThresholdOptions

    var body: some View {
        #if os(tvOS)
            tvOSBody
        #else
            defaultBody
        #endif
    }

    #if os(tvOS)
        // tvOS doesn't use a `Form`: its native row focus draws a clipped white
        // pill with an unreadable (non-inverting) label. A plain layout with our
        // contained-focus rows is fully legible and never truncated, and a
        // non-greedy `VStack` lets the sheet hug its content (no excess height).
        private var tvOSBody: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "Notifications"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)

                    FocusHighlightRow(action: { settingsStore.enableZeroCountNotification.toggle() }) {
                        HStack {
                            Text(String(localized: "Enable zero count notification"))
                            Spacer()
                            Text(settingsStore.enableZeroCountNotification
                                ? String(localized: "On")
                                : String(localized: "Off"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(String(localized: "High-count notification"))
                            Spacer()
                            Text(thresholdLabel)
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: highCountThresholdIndex,
                            in: 0 ... Double(Self.thresholdOptions.count - 1),
                            step: 1
                        )

                        HStack {
                            Text(String(localized: "Off"))
                            Spacer()
                            Text(500, format: .number)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(40)
                .navigationTitle(String(localized: "Settings"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                }
            }
            // The navigation stack is greedy; cap it so the sheet hugs the
            // content instead of leaving empty space below.
            .frame(maxHeight: 440)
        }
    #else
        private var defaultBody: some View {
            NavigationStack {
                Form {
                    #if os(macOS)
                        Section {
                            Toggle(
                                String(localized: "Show menu bar stats"),
                                isOn: $settingsStore.showMenuBarStats
                            )
                        }
                    #endif

                    Section(String(localized: "Notifications")) {
                        Toggle(String(localized: "Enable zero count notification"), isOn: $settingsStore.enableZeroCountNotification)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(localized: "High-count notification"))
                                Spacer()
                                Text(thresholdLabel)
                                    .foregroundStyle(.secondary)
                            }

                            Slider(
                                value: highCountThresholdIndex,
                                in: 0 ... Double(Self.thresholdOptions.count - 1),
                                step: 1
                            )

                            HStack {
                                Text(String(localized: "Off"))
                                Spacer()
                                Text(500, format: .number)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        #if os(macOS)
                            Toggle(
                                String(localized: "Bounce the Dock icon for notifications"),
                                isOn: $settingsStore.bounceDockOnNotification
                            )
                        #endif
                    }

                    // Siri tips only exist where the rolling Siri-tip view runs.
                    #if !os(watchOS)
                        Section {
                            Button(String(localized: "Reset Siri Tips")) {
                                settingsStore.showSiriTip = true
                            }
                        }
                    #endif
                }
                .navigationTitle(String(localized: "Settings"))
                #if os(macOS)
                    // Presented in the standard Settings window (⌘,), which
                    // already has its own close button — no "Done" needed.
                    .formStyle(.grouped)
                    .frame(width: 440, height: 360)
                #else
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(String(localized: "Done")) {
                                dismiss()
                            }
                        }
                    }
                #endif
            }
        }
    #endif

    private var thresholdLabel: String {
        let threshold = settingsStore.highCountNotificationThreshold
        return threshold <= 0 ? String(localized: "Off") : "\(threshold)"
    }

    private var highCountThresholdIndex: Binding<Double> {
        Binding(
            get: {
                let index = Self.thresholdOptions.firstIndex(of: settingsStore.highCountNotificationThreshold) ?? 0
                return Double(index)
            },
            set: { newValue in
                let roundedIndex = Int(newValue.rounded())
                let clampedIndex = min(max(roundedIndex, 0), Self.thresholdOptions.count - 1)
                settingsStore.highCountNotificationThreshold = Self.thresholdOptions[clampedIndex]
            }
        )
    }
}

#Preview("SettingsView") {
    SettingsView()
}
