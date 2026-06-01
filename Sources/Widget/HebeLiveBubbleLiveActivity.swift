import Foundation

// MARK: - Attributes (shared between the app and the widget extension)

#if canImport(ActivityKit) && (os(iOS) || os(visionOS)) && !targetEnvironment(macCatalyst)
    import ActivityKit

    /// Attributes describing the Hebe inventory Live Activity (the "bubble").
    ///
    /// Defined here so the app target (which starts and updates the activity)
    /// and the widget extension (which renders it) share the exact same type.
    struct HebeLiveBubbleAttributes: ActivityAttributes {
        struct ContentState: Codable, Hashable {
            var furnitureCount: Int
            var totalThingCount: Int
            var updatedAt: Date
        }

        var title: String
    }
#endif

// MARK: - Live Activity presentation (iPhone only — Lock Screen + Dynamic Island)

#if os(iOS) && !targetEnvironment(macCatalyst)
    import ActivityKit
    import SwiftUI
    import WidgetKit

    /// Renders ``HebeLiveBubbleAttributes`` as a Lock Screen card and in the
    /// Dynamic Island, showing the live furniture and item counts.
    struct HebeLiveBubbleLiveActivity: Widget {
        var body: some WidgetConfiguration {
            ActivityConfiguration(for: HebeLiveBubbleAttributes.self) { context in
                lockScreen(context.state, title: context.attributes.title)
                    .padding(14)
                    .activityBackgroundTint(.black.opacity(0.35))
                    .activitySystemActionForegroundColor(.primary)
            } dynamicIsland: { context in
                DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        countLabel(context.state.furnitureCount, systemImage: InventorySection.furniture.systemImage)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        countLabel(context.state.totalThingCount, systemImage: InventorySection.things.systemImage)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        Text(context.attributes.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } compactLeading: {
                    Image(systemName: InventorySection.furniture.systemImage)
                } compactTrailing: {
                    Text(context.state.totalThingCount, format: .number)
                        .monospacedDigit()
                } minimal: {
                    Image(systemName: InventorySection.things.systemImage)
                }
                .keylineTint(.orange)
            }
        }

        @ViewBuilder
        private func lockScreen(_ state: HebeLiveBubbleAttributes.ContentState, title: String) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                HStack {
                    countLabel(state.furnitureCount, systemImage: InventorySection.furniture.systemImage)
                    Spacer()
                    countLabel(state.totalThingCount, systemImage: InventorySection.things.systemImage)
                }
                Text("Updated \(state.updatedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        @ViewBuilder
        private func countLabel(_ value: Int, systemImage: String) -> some View {
            Label {
                Text(value, format: .number)
                    .monospacedDigit()
                    .bold()
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.orange)
            }
            .font(.title3)
        }
    }
#endif
