import AppIntents
import Foundation
import SwiftData
import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightIndexer {
    @MainActor
    static func reindex(using snapshot: InventorySnapshot, context: ModelContext) {
        let furnitures = (try? InventoryRepository.furnitureDigests(in: context)) ?? []
        let items = furnitures.map { furniture -> CSSearchableItem in
            let set = CSSearchableItemAttributeSet(contentType: .text)
            set.title = furniture.name
            set.contentDescription = furniture.things
                .map { L10n.Inventory.namedCount($0.name, count: $0.quantity) }
                .joined(separator: ", ")

            return CSSearchableItem(
                uniqueIdentifier: "furniture.\(furniture.name.lowercased())",
                domainIdentifier: "hebe.inventory",
                attributeSet: set
            )
        }

        let overall = CSSearchableItemAttributeSet(contentType: .text)
        overall.title = String(localized: "Hebe Inventory")
        overall.contentDescription = L10n.Inventory.spotlightSummary(
            furnitureCount: snapshot.furnitureCount,
            itemCount: snapshot.totalThingCount
        )

        let globalItem = CSSearchableItem(
            uniqueIdentifier: "inventory.summary",
            domainIdentifier: "hebe.inventory",
            attributeSet: overall
        )

        // iOS 18+: index the furniture/thing App Entities for semantic Spotlight
        // search (and Siri). The per-furniture manual items are then redundant,
        // so only the global summary stays manual.
        if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
            let furnitureEntities = furnitures.map { InventoryFurnitureEntity(id: $0.name, name: $0.name) }
            let thingEntities = Set(furnitures.flatMap(\.things).map(\.name))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { InventoryThingEntity(id: $0, name: $0) }

            Task {
                try? await CSSearchableIndex.default().indexAppEntities(furnitureEntities)
                try? await CSSearchableIndex.default().indexAppEntities(thingEntities)
            }
            CSSearchableIndex.default().indexSearchableItems([globalItem])
        } else {
            CSSearchableIndex.default().indexSearchableItems(items + [globalItem])
        }
    }
}
