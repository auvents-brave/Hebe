import AppIntents

struct HebeAppShortcutsProvider: AppShortcutsProvider {
	static let shortcutTileColor: ShortcutTileColor = .blue

	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: CountFurnitureIntent(),
			phrases: [
				"Count furniture in \(.applicationName)",
				"Get furniture count in \(.applicationName)",
				"How many furniture in \(.applicationName)",
			],
			shortTitle: "Count Furniture",
			systemImageName: "square.stack.3d.up"
		)
		AppShortcut(
			intent: CountThingsIntent(),
			phrases: [
				"Count things in \(.applicationName)",
				"Get thing count in \(.applicationName)",
				"How many things in \(.applicationName)",
			],
			shortTitle: "Count Things",
			systemImageName: "shippingbox"
		)
		AppShortcut(
			intent: FurnitureContentsIntent(),
			phrases: [
				"Show furniture contents in \(.applicationName)",
				"Get furniture contents in \(.applicationName)",
			],
			shortTitle: "Furniture Contents",
			systemImageName: "shippingbox.circle"
		)
		AppShortcut(
			intent: FurnituresContainingThingIntent(),
			phrases: [
				"Find furniture by thing in \(.applicationName)",
				"Show furniture for thing in \(.applicationName)",
			],
			shortTitle: "Find Furniture by Thing",
			systemImageName: "magnifyingglass"
		)
	}
}
