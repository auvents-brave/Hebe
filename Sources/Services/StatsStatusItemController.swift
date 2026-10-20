import AppKit
import SwiftUI

@MainActor
final class StatsStatusItemController: NSObject, NSMenuDelegate {
	private let menu: NSMenu
	private let menuItem: NSMenuItem
	private let hostingView: NSHostingView<StatsMenuView>
	private let statusItem: NSStatusItem

	override init() {
		menu = NSMenu()
		menuItem = NSMenuItem()
		hostingView = NSHostingView(rootView: StatsMenuView(snapshot: InventorySnapshotStore.load()))
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

		super.init()

		menuItem.view = hostingView
		menu.addItem(menuItem)
		menu.delegate = self

		if let button = statusItem.button {
			button.image = NSImage(
				systemSymbolName: "chart.bar",
				accessibilityDescription: String(localized: "Stats")
			)
			button.toolTip = String(localized: "Inventory Stats")
		}
		statusItem.menu = menu
	}

	func menuWillOpen(_ menu: NSMenu) {
		hostingView.rootView = StatsMenuView(snapshot: InventorySnapshotStore.load())
		hostingView.layoutSubtreeIfNeeded()
		let size = hostingView.fittingSize
		hostingView.setFrameSize(size)
	}

	func remove() {
		NSStatusBar.system.removeStatusItem(statusItem)
	}
}

private struct StatsMenuView: View {
	let snapshot: InventorySnapshot

	var body: some View {
		// Same shared pills as the main screen: icons + identical labels.
		InventoryStatsView(snapshot: snapshot)
			.frame(width: 220, alignment: .leading)
			.padding(8)
	}
}

#Preview("StatsMenuView") {
	StatsMenuView(snapshot: PreviewData.snapshot())
}
