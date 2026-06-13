import Foundation

struct ThingDigest: Codable, Hashable, Sendable {
	let name: String
	let quantity: Int
}

struct FurnitureDigest: Codable, Hashable, Sendable {
	let name: String
	let things: [ThingDigest]
}

struct InventorySnapshot: Codable, Hashable, Sendable {
	let generatedAt: Date
	let furnitureCount: Int
	let distinctThingCount: Int
	let totalThingCount: Int

	static let empty = InventorySnapshot(
		generatedAt: .now,
		furnitureCount: 0,
		distinctThingCount: 0,
		totalThingCount: 0
	)
}

// MARK: - Headline stats (single source for the app pills and the widget)

/// One headline inventory statistic — its label, SF Symbol and value.
///
/// Defined once so the app's stat pills and the widget show identical content.
struct InventoryStat: Identifiable, Sendable {
	enum Kind: String, Sendable { case furniture, distinctThings, things }

	let kind: Kind
	var id: String { kind.rawValue }
	let label: String
	let systemImage: String
	let value: Int
}

extension InventorySnapshot {
	/// The three headline stats — furniture, distinct things, total things.
	var stats: [InventoryStat] {
		[
			InventoryStat(
				kind: .furniture,
				label: String(localized: "Furniture count"),
				systemImage: InventorySection.furniture.systemImage,
				value: furnitureCount
			),
			InventoryStat(
				kind: .distinctThings,
				label: String(localized: "Distinct things"),
				systemImage: "square.grid.2x2",
				value: distinctThingCount
			),
			InventoryStat(
				kind: .things,
				label: String(localized: "Things count"),
				systemImage: InventorySection.things.systemImage,
				value: totalThingCount
			),
		]
	}
}

enum InventoryMath {
	static func makeSnapshot(from furnitures: [FurnitureDigest], date: Date = .now) -> InventorySnapshot {
		let distinctThingCount = Set(
			furnitures
				.flatMap(\.things)
				.map { $0.name.lowercased() }
		).count

		let totalThingCount =
			furnitures
			.flatMap(\.things)
			.reduce(0) { $0 + max(0, $1.quantity) }

		return InventorySnapshot(
			generatedAt: date,
			furnitureCount: furnitures.count,
			distinctThingCount: distinctThingCount,
			totalThingCount: totalThingCount
		)
	}

	static func normalizedDigests(_ furnitures: [FurnitureDigest]) -> [FurnitureDigest] {
		var thingNamesByFurnitureKey: [String: [String: String]] = [:]
		var quantitiesByFurnitureKey: [String: [String: Int]] = [:]
		var furnitureNamesByKey: [String: String] = [:]

		for furniture in furnitures {
			let furnitureName = cleanedName(furniture.name)
			let furnitureKey = normalizedLookupKey(furnitureName)
			guard furnitureKey.isEmpty == false else { continue }

			if furnitureNamesByKey[furnitureKey] == nil {
				furnitureNamesByKey[furnitureKey] = furnitureName
			}

			for thing in furniture.things {
				let thingName = cleanedName(thing.name)
				let thingKey = normalizedLookupKey(thingName)
				let quantity = max(0, thing.quantity)

				guard thingKey.isEmpty == false, quantity > 0 else { continue }

				quantitiesByFurnitureKey[furnitureKey, default: [:]][thingKey, default: 0] += quantity
				if thingNamesByFurnitureKey[furnitureKey]?[thingKey] == nil {
					thingNamesByFurnitureKey[furnitureKey, default: [:]][thingKey] = thingName
				}
			}
		}

		return
			quantitiesByFurnitureKey
			.compactMap { furnitureKey, thingsByKey -> FurnitureDigest? in
				guard let furnitureName = furnitureNamesByKey[furnitureKey] else {
					return nil
				}

				let things =
					thingsByKey
					.compactMap { thingKey, quantity -> ThingDigest? in
						guard let thingName = thingNamesByFurnitureKey[furnitureKey]?[thingKey] else {
							return nil
						}

						return ThingDigest(name: thingName, quantity: quantity)
					}
					.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

				guard things.isEmpty == false else {
					return nil
				}

				return FurnitureDigest(name: furnitureName, things: things)
			}
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	static func cleanedName(_ value: String) -> String {
		value.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	static func normalizedLookupKey(_ value: String) -> String {
		cleanedName(value).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
	}
}

enum InventorySnapshotStore {
	private static var defaults: UserDefaults {
		UserDefaults(suiteName: SharedConstants.appGroupIdentifier) ?? .standard
	}

	private static var snapshotFileURL: URL? {
		guard
			let containerURL = FileManager.default.containerURL(
				forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
			)
		else {
			return nil
		}

		let directoryURL = containerURL.appendingPathComponent("TopShelf", isDirectory: true)
		try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
		return directoryURL.appendingPathComponent("inventory_snapshot.json")
	}

	static func load() -> InventorySnapshot {
		if let fileURL = snapshotFileURL,
			let data = try? Data(contentsOf: fileURL),
			let snapshot = try? JSONDecoder().decode(InventorySnapshot.self, from: data)
		{
			return snapshot
		}

		guard let data = defaults.data(forKey: SharedConstants.inventorySnapshotKey),
			let snapshot = try? JSONDecoder().decode(InventorySnapshot.self, from: data)
		else {
			return .empty
		}
		return snapshot
	}

	static func save(_ snapshot: InventorySnapshot) {
		guard let data = try? JSONEncoder().encode(snapshot) else { return }

		if let fileURL = snapshotFileURL {
			try? data.write(to: fileURL, options: .atomic)
		}

		defaults.set(data, forKey: SharedConstants.inventorySnapshotKey)
		defaults.synchronize()
	}
}
