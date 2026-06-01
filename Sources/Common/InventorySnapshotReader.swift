import Foundation
import SwiftData

enum InventorySnapshotReader {
    static func loadCurrent() -> InventorySnapshot {
        if let snapshot = loadFromPersistentStore() {
            return snapshot
        }

        return InventorySnapshotStore.load()
    }

    private static func loadFromPersistentStore() -> InventorySnapshot? {
        guard let container = try? PersistenceController.makeContainer(useCloudKit: false) else {
            return nil
        }

        let context = ModelContext(container)

        guard let fetchedFurnitures = try? context.fetch(FetchDescriptor<Furniture>()) else {
            return nil
        }

        let furnitures = fetchedFurnitures.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        let digests = furnitures.map { furniture in
            let slots: [FurnitureThing] = furniture.slots ?? []
            let things = slots.compactMap { slot -> ThingDigest? in
                guard let thingName = slot.thing?.name else { return nil }
                return ThingDigest(name: thingName, quantity: slot.quantity)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            return FurnitureDigest(name: furniture.name, things: things)
        }

        return InventoryMath.makeSnapshot(from: digests)
    }
}
