import Foundation

enum L10n {
	enum Inventory {
		static func siriTip(_ phrase: String) -> String {
			String(localized: "Siri Tip: \"\(phrase)\"")
		}

		static func namedCount(_ name: String, count: Int) -> String {
			String(localized: "\(name): \(count)")
		}

		static func spotlightSummary(furnitureCount: Int, itemCount: Int) -> String {
			String(
				localized: "Furniture: \(furnitureCount), Items: \(itemCount)"
			)
		}
	}

	enum Notifications {
		static func thresholdReachedBody(currentTotal: Int, threshold: Int) -> String {
			String(
				localized: "Things count is \(currentTotal), above your threshold of \(threshold)."
			)
		}
	}

	enum TopShelf {
		static let title = String(localized: "Hebe Inventory")

		static func counts(furniture: Int, types: Int, total: Int) -> String {
			String(
				localized: "Furniture \(furniture)  •  Distinct things \(types)  •  Things \(total)"
			)
		}
	}

	enum Intents {
		static func countFurnitureResult(_ count: Int) -> String {
			String(
				localized: "You currently have \(count) furniture entries."
			)
		}

		static func countThingsResult(_ total: Int) -> String {
			String(
				localized: "You currently have \(total) things in total."
			)
		}

		static func noFurnitureFound(named furnitureName: String) -> String {
			String(
				localized: "No furniture named \(furnitureName) was found."
			)
		}

		static func furnitureEmpty(_ furnitureName: String) -> String {
			String(
				localized: "\(furnitureName) is currently empty."
			)
		}

		static func furnitureContains(name: String, contents: String) -> String {
			String(
				localized: "\(name) contains \(contents)."
			)
		}

		static func noFurnitureContains(_ thingName: String) -> String {
			String(
				localized: "No furniture contains \(thingName)."
			)
		}
	}
}
