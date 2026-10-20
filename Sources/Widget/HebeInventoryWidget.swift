import SwiftUI
import WidgetKit

struct HebeWidgetEntry: TimelineEntry {
	let date: Date
	let snapshot: InventorySnapshot
}

struct HebeWidgetProvider: TimelineProvider {
	func placeholder(in context: Context) -> HebeWidgetEntry {
		HebeWidgetEntry(date: .now, snapshot: .empty)
	}

	func getSnapshot(in context: Context, completion: @escaping (HebeWidgetEntry) -> Void) {
		completion(HebeWidgetEntry(date: .now, snapshot: InventorySnapshotReader.loadCurrent()))
	}

	func getTimeline(in context: Context, completion: @escaping (Timeline<HebeWidgetEntry>) -> Void) {
		let snapshot = InventorySnapshotReader.loadCurrent()
		let now = Date()
		let entries = (0..<60).map { offset in
			HebeWidgetEntry(date: now.addingTimeInterval(TimeInterval(offset)), snapshot: snapshot)
		}
		let nextRefresh = now.addingTimeInterval(60)
		completion(Timeline(entries: entries, policy: .after(nextRefresh)))
	}
}

struct HebeInventoryWidget: Widget {
	private var supportedFamilies: [WidgetFamily] {
		var families: [WidgetFamily] = []
		#if !os(watchOS)
			families.append(contentsOf: [
				.systemSmall,
				.systemMedium,
				.systemLarge,
				.systemExtraLarge,
			])
		#endif
		#if !os(visionOS) && !os(macOS)
			families.append(contentsOf: [
				.accessoryInline,
				.accessoryRectangular,
				.accessoryCircular,
			])
		#endif
		#if os(watchOS)
			families.append(.accessoryCorner)
		#endif
		return families
	}

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: SharedConstants.widgetKind, provider: HebeWidgetProvider()) { entry in
			HebeInventoryWidgetView(entry: entry)
				.widgetURL(URL(string: "hebe://furniture"))
		}
		.configurationDisplayName(String(localized: "Hebe Inventory"))
		.description(String(localized: "Shows live time, furniture count and total things."))
		.supportedFamilies(supportedFamilies)
	}
}

private struct HebeInventoryWidgetView: View {
	let entry: HebeWidgetEntry

	@Environment(\.widgetFamily) private var family

	var body: some View {
		Group {
			switch family {
			#if !os(visionOS) && !os(macOS)
				case .accessoryInline:
					AccessoryInlineView(snapshot: entry.snapshot)
				case .accessoryCircular:
					AccessoryCircularView(snapshot: entry.snapshot)
				case .accessoryRectangular:
					AccessoryRectangularView(snapshot: entry.snapshot)
			#endif
			#if os(watchOS)
				case .accessoryCorner:
					AccessoryCornerView(snapshot: entry.snapshot)
			#endif
			default:
				ZStack(alignment: .topLeading) {
					WidgetPillsView(snapshot: entry.snapshot, family: family)
						.frame(maxWidth: .infinity, maxHeight: .infinity)

					#if DEBUG
						Text("15:14")

						HStack(spacing: 4) {
							Text(entry.date, format: .dateTime.hour().minute().second())
								.font(.headline)
								.monospacedDigit()
						}
						.padding(8)
					#endif
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.containerBackground(.fill.tertiary, for: .widget)
	}
}

private struct AccessoryInlineView: View {
	let snapshot: InventorySnapshot

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: InventorySection.things.systemImage)
			Text(snapshot.totalThingCount, format: .number)
				.monospacedDigit()
		}
	}
}

private struct AccessoryCircularView: View {
	let snapshot: InventorySnapshot

	var body: some View {
		ZStack {
			Circle()
				.fill(.tertiary)
			VStack(spacing: 2) {
				Image(systemName: InventorySection.things.systemImage)
				Text(snapshot.totalThingCount, format: .number)
					.font(.caption2)
					.monospacedDigit()
			}
		}
	}
}

private struct AccessoryRectangularView: View {
	let snapshot: InventorySnapshot

	var body: some View {
		HStack(spacing: 6) {
			HStack(spacing: 4) {
				Image(systemName: InventorySection.furniture.systemImage)
				Text(snapshot.furnitureCount, format: .number)
					.monospacedDigit()
			}
			Spacer(minLength: 6)
			HStack(spacing: 4) {
				Image(systemName: InventorySection.things.systemImage)
				Text(snapshot.totalThingCount, format: .number)
					.monospacedDigit()
			}
		}
	}
}

#if os(watchOS)
	/// Corner complication: the things icon in the corner, with the total count
	/// curving along the bezel.
	private struct AccessoryCornerView: View {
		let snapshot: InventorySnapshot

		var body: some View {
			Image(systemName: InventorySection.things.systemImage)
				.widgetLabel {
					Text(snapshot.totalThingCount, format: .number)
				}
		}
	}
#endif

private struct WidgetPillsView: View {
	let snapshot: InventorySnapshot
	let family: WidgetFamily

	var body: some View {
		let spacing: CGFloat = 6
		let contentInset: CGFloat = 8
		let pills = pillsForFamily

		GeometryReader { proxy in
			let availableHeight = max(0, proxy.size.height - contentInset * 2)
			let totalSpacing = spacing * max(0, CGFloat(pills.count - 1))
			let pillHeight = pills.isEmpty ? 0 : max(0, (availableHeight - totalSpacing) / CGFloat(pills.count))
			VStack(alignment: .leading, spacing: spacing) {
				ForEach(pills.indices, id: \.self) { index in
					pills[index]
						.frame(height: pillHeight)
				}
			}
			.frame(width: proxy.size.width - contentInset * 2, height: availableHeight, alignment: .topLeading)
			.padding(contentInset)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var pillsForFamily: [WidgetPill] {
		let stats = snapshot.stats
		func pill(_ stat: InventoryStat, showLabel: Bool) -> WidgetPill {
			WidgetPill(label: showLabel ? stat.label : nil, value: stat.value, iconName: stat.systemImage)
		}
		// Compact families drop the "distinct things" stat to save room.
		let compact = stats.filter { $0.kind != .distinctThings }
		switch family {
		#if !os(visionOS) && !os(macOS)
			case .accessoryInline, .accessoryCircular, .accessoryRectangular:
				return compact.map { pill($0, showLabel: true) }
		#endif
		case .systemSmall:
			return compact.map { pill($0, showLabel: false) }
		default:
			return stats.map { pill($0, showLabel: true) }
		}
	}
}

private struct WidgetPill: View {
	let label: String?
	let value: Int
	let iconName: String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: iconName)
				.foregroundStyle(.secondary)

			if let label {
				Text(label)
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 8)
			Text(value, format: .number)
				.font(.headline)
				.monospacedDigit()
		}
		.padding(8)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		.background(Color.secondary.opacity(0.12))
		.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
	}
}

private enum WidgetPreviewData {
	static func entry() -> HebeWidgetEntry {
		let snapshot = InventorySnapshot(
			generatedAt: .now,
			furnitureCount: Int.random(in: 3...9),
			distinctThingCount: Int.random(in: 5...16),
			totalThingCount: Int.random(in: 20...180)
		)
		return HebeWidgetEntry(date: .now, snapshot: snapshot)
	}
}

#if !os(watchOS)
	#Preview("systemSmall", as: .systemSmall) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}

	#Preview("systemMedium", as: .systemMedium) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}

	#Preview("systemLarge", as: .systemLarge) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}

	#Preview("systemExtraLarge", as: .systemExtraLarge) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}
#endif

#if !os(visionOS) && !os(macOS)
	#Preview("accessoryInline", as: .accessoryInline) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}

	#Preview("accessoryCircular", as: .accessoryCircular) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}

	#Preview("accessoryRectangular", as: .accessoryRectangular) {
		HebeInventoryWidget()
	} timeline: {
		WidgetPreviewData.entry()
	}
#endif
