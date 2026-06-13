import Foundation
import SwiftData

@Model
final class FurnitureThing {
	var id: UUID = UUID()
	var quantity: Int = 0

	var furniture: Furniture?
	var thing: Thing?

	init(quantity: Int, furniture: Furniture, thing: Thing) {
		self.quantity = quantity
		self.furniture = furniture
		self.thing = thing
	}
}
