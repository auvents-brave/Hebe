import Foundation
import Testing

@testable import Hebe

struct HebeInventoryMathTests {
	@Test("Inventory snapshot aggregates furniture and thing quantities")
	func snapshotAggregation() {
		let furnitures = [
			FurnitureDigest(
				name: "Shelf",
				things: [
					ThingDigest(name: "Books", quantity: 8),
					ThingDigest(name: "Cables", quantity: 3),
				]),
			FurnitureDigest(
				name: "Desk",
				things: [
					ThingDigest(name: "Cables", quantity: 4),
					ThingDigest(name: "Screws", quantity: 20),
				]),
		]

		let snapshot = InventoryMath.makeSnapshot(from: furnitures, date: Date(timeIntervalSince1970: 0))

		#expect(snapshot.furnitureCount == 2)
		#expect(snapshot.distinctThingCount == 3)
		#expect(snapshot.totalThingCount == 35)
	}
}
