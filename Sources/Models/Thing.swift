import Foundation
import SwiftData

@Model
final class Thing {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Foundation.Date.now

    @Relationship(deleteRule: .cascade, inverse: \FurnitureThing.thing)
    var slots: [FurnitureThing]?

    init(name: String, createdAt: Date = Foundation.Date.now) {
        self.name = name
        self.createdAt = createdAt
        slots = []
    }
}
