import Foundation
import SwiftData

@MainActor
enum InventoryRepository {
    static func ensureSeedData(in context: ModelContext, iCloudAvailable: Bool) async throws {
        if iCloudAvailable {
            for _ in 0..<6 {
                let existingCount = try context.fetchCount(FetchDescriptor<Furniture>())
                if existingCount > 0 { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        let existingCount = try context.fetchCount(FetchDescriptor<Furniture>())
        guard existingCount == 0 else { return }

        let screws = Thing(name: "Screws")
        let books = Thing(name: "Books")
        let cables = Thing(name: "Cables")
        let batteries = Thing(name: "Batteries")

        let shelf = Furniture(name: "Living Room Shelf")
        let cabinet = Furniture(name: "Hallway Cabinet")
        let desk = Furniture(name: "Office Desk")

        context.insert(screws)
        context.insert(books)
        context.insert(cables)
        context.insert(batteries)
        context.insert(shelf)
        context.insert(cabinet)
        context.insert(desk)

        context.insert(FurnitureThing(quantity: 12, furniture: shelf, thing: books))
        context.insert(FurnitureThing(quantity: 24, furniture: shelf, thing: screws))
        context.insert(FurnitureThing(quantity: 8, furniture: cabinet, thing: batteries))
        context.insert(FurnitureThing(quantity: 6, furniture: cabinet, thing: cables))
        context.insert(FurnitureThing(quantity: 14, furniture: desk, thing: screws))
        context.insert(FurnitureThing(quantity: 9, furniture: desk, thing: cables))

        try context.save()
    }

    static func deleteAll(in context: ModelContext) throws {
        let furnitures = try context.fetch(FetchDescriptor<Furniture>())
        let things = try context.fetch(FetchDescriptor<Thing>())

        for furniture in furnitures {
            context.delete(furniture)
        }
        for thing in things {
            context.delete(thing)
        }

        try context.save()
    }

    /// Deletes the furnitures whose normalized name matches one of `keys`.
    static func deleteFurnitures(matchingKeys keys: Set<String>, in context: ModelContext) throws {
        guard keys.isEmpty == false else { return }
        let furnitures = try context.fetch(FetchDescriptor<Furniture>())
        for furniture in furnitures where keys.contains(InventoryMath.normalizedLookupKey(furniture.name)) {
            context.delete(furniture)
        }
        try context.save()
    }

    /// Deletes the things whose name matches one of `names` (removing them from
    /// every furniture).
    static func deleteThings(named names: Set<String>, in context: ModelContext) throws {
        guard names.isEmpty == false else { return }
        let things = try context.fetch(FetchDescriptor<Thing>())
        for thing in things where names.contains(thing.name) {
            context.delete(thing)
        }
        try context.save()
    }

    static func fillRandomData(in context: ModelContext) throws {
        let furnitureNames = [
            "Living Room Shelf", "Hallway Cabinet", "Office Desk", "Kitchen Pantry",
            "Garage Rack", "Bedroom Dresser", "Studio Cabinet", "Laundry Shelf"
        ]
        let thingNames = [
            "Screws", "Books", "Cables", "Batteries", "Bulbs", "Notebooks",
            "Tools", "Adapters", "Envelopes", "Tapes", "Markers", "Hooks"
        ]

        let furnitureCount = Int.random(in: 3...min(7, furnitureNames.count))
        let thingCount = Int.random(in: 6...min(12, thingNames.count))

        // Reuse existing furnitures and things by name so repeated fills don't
        // create duplicate-named entities (a thing is a shared type) or
        // duplicate slots — quantities accumulate on the existing slot instead.
        var furnitureByKey: [String: Furniture] = [:]
        for furniture in try context.fetch(FetchDescriptor<Furniture>()) {
            let key = InventoryMath.normalizedLookupKey(furniture.name)
            if furnitureByKey[key] == nil { furnitureByKey[key] = furniture }
        }

        var thingByKey: [String: Thing] = [:]
        for thing in try context.fetch(FetchDescriptor<Thing>()) {
            let key = InventoryMath.normalizedLookupKey(thing.name)
            if thingByKey[key] == nil { thingByKey[key] = thing }
        }

        func furniture(named name: String) -> Furniture {
            let key = InventoryMath.normalizedLookupKey(name)
            if let existing = furnitureByKey[key] { return existing }
            let new = Furniture(name: name)
            context.insert(new)
            furnitureByKey[key] = new
            return new
        }

        func thing(named name: String) -> Thing {
            let key = InventoryMath.normalizedLookupKey(name)
            if let existing = thingByKey[key] { return existing }
            let new = Thing(name: name)
            context.insert(new)
            thingByKey[key] = new
            return new
        }

        let furnitures = furnitureNames.shuffled().prefix(furnitureCount).map { furniture(named: $0) }
        let things = thingNames.shuffled().prefix(thingCount).map { thing(named: $0) }

        for furniture in furnitures {
            var slotByThingKey: [String: FurnitureThing] = [:]
            for slot in furniture.slots ?? [] {
                guard let thingName = slot.thing?.name else { continue }
                let key = InventoryMath.normalizedLookupKey(thingName)
                if slotByThingKey[key] == nil { slotByThingKey[key] = slot }
            }

            let slotCount = Int.random(in: 2...min(6, things.count))
            let selection = Array(things.shuffled().prefix(slotCount))
            for thing in selection {
                let quantity = Int.random(in: 1...30)
                let key = InventoryMath.normalizedLookupKey(thing.name)
                if let slot = slotByThingKey[key] {
                    slot.quantity += quantity
                } else {
                    let slot = FurnitureThing(quantity: quantity, furniture: furniture, thing: thing)
                    context.insert(slot)
                    slotByThingKey[key] = slot
                }
            }
        }

        try context.save()
    }

    static func furnitureDigests(in context: ModelContext) throws -> [FurnitureDigest] {
        let furnitures = try context.fetch(FetchDescriptor<Furniture>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        ))

        return furnitures.map { furniture in
            let things = (furniture.slots ?? []).compactMap { slot -> ThingDigest? in
                guard let thingName = slot.thing?.name else { return nil }
                return ThingDigest(name: thingName, quantity: slot.quantity)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            return FurnitureDigest(name: furniture.name, things: things)
        }
    }

    static func replaceInventory(with digests: [FurnitureDigest], in context: ModelContext) throws {
        try deleteAll(in: context)

        var thingByName: [String: Thing] = [:]

        for furnitureDigest in digests {
            let furniture = Furniture(name: furnitureDigest.name)
            context.insert(furniture)

            for thingDigest in furnitureDigest.things {
                let key = thingDigest.name.lowercased()
                let thing: Thing
                if let existingThing = thingByName[key] {
                    thing = existingThing
                } else {
                    let newThing = Thing(name: thingDigest.name)
                    context.insert(newThing)
                    thingByName[key] = newThing
                    thing = newThing
                }

                context.insert(FurnitureThing(
                    quantity: max(0, thingDigest.quantity),
                    furniture: furniture,
                    thing: thing
                ))
            }
        }

        try context.save()
    }

    static func mergeInventory(with digests: [FurnitureDigest], in context: ModelContext) throws {
        let normalizedDigests = InventoryMath.normalizedDigests(digests)
        guard normalizedDigests.isEmpty == false else { return }

        let existingFurnitures = try context.fetch(FetchDescriptor<Furniture>())
        var furnitureByKey: [String: Furniture] = [:]
        for furniture in existingFurnitures {
            let key = InventoryMath.normalizedLookupKey(furniture.name)
            if furnitureByKey[key] == nil {
                furnitureByKey[key] = furniture
            }
        }

        let existingThings = try context.fetch(FetchDescriptor<Thing>())
        var thingByKey: [String: Thing] = [:]
        for thing in existingThings {
            let key = InventoryMath.normalizedLookupKey(thing.name)
            if thingByKey[key] == nil {
                thingByKey[key] = thing
            }
        }

        for furnitureDigest in normalizedDigests {
            let furnitureKey = InventoryMath.normalizedLookupKey(furnitureDigest.name)
            let furniture: Furniture

            if let existingFurniture = furnitureByKey[furnitureKey] {
                furniture = existingFurniture
            } else {
                let newFurniture = Furniture(name: furnitureDigest.name)
                context.insert(newFurniture)
                furnitureByKey[furnitureKey] = newFurniture
                furniture = newFurniture
            }

            var slotByThingKey: [String: FurnitureThing] = [:]
            for slot in furniture.slots ?? [] {
                guard let thingName = slot.thing?.name else { continue }
                let key = InventoryMath.normalizedLookupKey(thingName)
                if slotByThingKey[key] == nil {
                    slotByThingKey[key] = slot
                }
            }

            for thingDigest in furnitureDigest.things {
                let thingKey = InventoryMath.normalizedLookupKey(thingDigest.name)
                let quantity = max(0, thingDigest.quantity)

                guard quantity > 0 else { continue }

                let thing: Thing
                if let existingThing = thingByKey[thingKey] {
                    thing = existingThing
                } else {
                    let newThing = Thing(name: thingDigest.name)
                    context.insert(newThing)
                    thingByKey[thingKey] = newThing
                    thing = newThing
                }

                if let slot = slotByThingKey[thingKey] {
                    slot.quantity += quantity
                } else {
                    let slot = FurnitureThing(quantity: quantity, furniture: furniture, thing: thing)
                    context.insert(slot)
                    slotByThingKey[thingKey] = slot
                }
            }
        }

        try context.save()
    }

    static func snapshot(in context: ModelContext) throws -> InventorySnapshot {
        InventoryMath.makeSnapshot(from: try furnitureDigests(in: context))
    }

    static func hasFurniture(in context: ModelContext) throws -> Bool {
        try context.fetchCount(FetchDescriptor<Furniture>()) > 0
    }

    static func furnitureContents(named furnitureName: String, in context: ModelContext) throws -> [ThingDigest]? {
        let digests = try furnitureDigests(in: context)
        return digests.first(where: { $0.name.localizedCaseInsensitiveCompare(furnitureName) == .orderedSame })?.things
    }

    static func furnitures(containing thingName: String, in context: ModelContext) throws -> [FurnitureDigest] {
        let digests = try furnitureDigests(in: context)
        return digests.filter { furniture in
            furniture.things.contains { $0.name.localizedCaseInsensitiveCompare(thingName) == .orderedSame }
        }
    }
}
