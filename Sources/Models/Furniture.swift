import Foundation
import SwiftData

@Model
final class Furniture {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Foundation.Date.now

    @Relationship(deleteRule: .cascade, inverse: \FurnitureThing.furniture)
    var slots: [FurnitureThing]?

    init(name: String, createdAt: Date = Foundation.Date.now) {
        self.name = name
        self.createdAt = createdAt
        slots = []
    }
}
