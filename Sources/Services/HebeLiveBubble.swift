import Foundation

#if canImport(ActivityKit) && (os(iOS) || os(visionOS)) && !targetEnvironment(macCatalyst)
	import ActivityKit

	// `HebeLiveBubbleAttributes` lives in HebeLiveBubbleLiveActivity.swift,
	// shared with the widget extension that renders the activity.

	@MainActor
	final class LiveBubbleManager {
		static let shared = LiveBubbleManager()

		private var activityID: String?

		func update(with snapshot: InventorySnapshot) {
			guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

			let state = HebeLiveBubbleAttributes.ContentState(
				furnitureCount: snapshot.furnitureCount,
				totalThingCount: snapshot.totalThingCount,
				updatedAt: snapshot.generatedAt
			)

			if let activityID {
				Task.detached {
					let currentActivity = Activity<HebeLiveBubbleAttributes>.activities.first { $0.id == activityID }
					await currentActivity?.update(ActivityContent(state: state, staleDate: nil))
				}
				return
			}

			let attributes = HebeLiveBubbleAttributes(title: "Hebe")
			let activity = try? Activity.request(
				attributes: attributes,
				content: ActivityContent(state: state, staleDate: nil),
				pushType: nil
			)
			activityID = activity?.id
		}
	}
#else
	@MainActor
	final class LiveBubbleManager {
		static let shared = LiveBubbleManager()

		func update(with snapshot: InventorySnapshot) {}
	}
#endif
