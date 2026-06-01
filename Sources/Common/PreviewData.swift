import SwiftData

@MainActor
enum PreviewData {
    static func container() -> ModelContainer {
        let schema = Schema([Furniture.self, Thing.self, FurnitureThing.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        try? InventoryRepository.fillRandomData(in: context)
        return container
    }

    static func snapshot() -> InventorySnapshot {
        let digests = furnitureDigests()
        return InventoryMath.makeSnapshot(from: digests)
    }

    static func furnitures() -> [Furniture] {
        sampleData().furnitures
    }

    static func things() -> [Thing] {
        sampleData().things
    }

    private static func furnitureDigests() -> [FurnitureDigest] {
        sampleData().furnitures.map { furniture in
            let things = (furniture.slots ?? []).compactMap { slot -> ThingDigest? in
                guard let thingName = slot.thing?.name else { return nil }
                return ThingDigest(name: thingName, quantity: slot.quantity)
            }
            return FurnitureDigest(name: furniture.name, things: things)
        }
    }

    private static func sampleData() -> (furnitures: [Furniture], things: [Thing]) {
        let screws = Thing(name: "Screws")
        let books = Thing(name: "Books")
        let cables = Thing(name: "Cables")
        let batteries = Thing(name: "Batteries")

        let shelf = Furniture(name: "Living Room Shelf")
        let cabinet = Furniture(name: "Hallway Cabinet")
        let desk = Furniture(name: "Office Desk")

        let shelfBooks = FurnitureThing(quantity: 12, furniture: shelf, thing: books)
        let shelfScrews = FurnitureThing(quantity: 24, furniture: shelf, thing: screws)
        let cabinetBatteries = FurnitureThing(quantity: 8, furniture: cabinet, thing: batteries)
        let cabinetCables = FurnitureThing(quantity: 6, furniture: cabinet, thing: cables)
        let deskScrews = FurnitureThing(quantity: 14, furniture: desk, thing: screws)
        let deskCables = FurnitureThing(quantity: 9, furniture: desk, thing: cables)

        shelf.slots = [shelfBooks, shelfScrews]
        cabinet.slots = [cabinetBatteries, cabinetCables]
        desk.slots = [deskScrews, deskCables]

        screws.slots = [shelfScrews, deskScrews]
        books.slots = [shelfBooks]
        cables.slots = [cabinetCables, deskCables]
        batteries.slots = [cabinetBatteries]

        return ([shelf, cabinet, desk], [screws, books, cables, batteries])
    }
}
