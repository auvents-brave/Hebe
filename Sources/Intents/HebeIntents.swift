import AppIntents
import Foundation
import SwiftData

private enum IntentInventoryData {
    @MainActor
    static func digests() -> [FurnitureDigest] {
        let context = ModelContext(PersistenceController.shared)
        return (try? InventoryRepository.furnitureDigests(in: context)) ?? []
    }

    @MainActor
    static func furnitureEntities() -> [InventoryFurnitureEntity] {
        digests().map { digest in
            InventoryFurnitureEntity(id: digest.name, name: digest.name)
        }
    }

    @MainActor
    static func thingEntities() -> [InventoryThingEntity] {
        let uniqueThingNames = Set(
            digests()
                .flatMap(\.things)
                .map(\.name)
        )

        return uniqueThingNames
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { InventoryThingEntity(id: $0, name: $0) }
    }
}

struct InventoryFurnitureEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Furniture"
    static let defaultQuery = InventoryFurnitureQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct InventoryThingEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Thing"
    static let defaultQuery = InventoryThingQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// Indexed into Spotlight (iOS 18+) for semantic search via `indexAppEntities`.
// `IndexedEntity` doesn't exist on tvOS (no CoreSpotlight), hence the `#if`.
#if !os(tvOS)
    @available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
    extension InventoryFurnitureEntity: IndexedEntity {}

    @available(iOS 18.0, macOS 15.0, watchOS 11.0, visionOS 2.0, *)
    extension InventoryThingEntity: IndexedEntity {}
#endif

struct InventoryFurnitureQuery: EntityStringQuery {
    func entities(for identifiers: [InventoryFurnitureEntity.ID]) async throws -> [InventoryFurnitureEntity] {
        await MainActor.run {
            let entities = IntentInventoryData.furnitureEntities()
            let ids = Set(identifiers)
            return entities.filter { ids.contains($0.id) }
        }
	}

    func entities(matching string: String) async throws -> [InventoryFurnitureEntity] {
        await MainActor.run {
            let key = InventoryMath.normalizedLookupKey(string)
            guard key.isEmpty == false else { return IntentInventoryData.furnitureEntities() }
            return IntentInventoryData.furnitureEntities().filter {
                InventoryMath.normalizedLookupKey($0.name).contains(key)
            }
        }
    }

    func suggestedEntities() async throws -> [InventoryFurnitureEntity] {
        await MainActor.run {
            IntentInventoryData.furnitureEntities()
        }
    }
}

struct InventoryThingQuery: EntityStringQuery {
    func entities(for identifiers: [InventoryThingEntity.ID]) async throws -> [InventoryThingEntity] {
        await MainActor.run {
            let entities = IntentInventoryData.thingEntities()
            let ids = Set(identifiers)
            return entities.filter { ids.contains($0.id) }
        }
    }

    func entities(matching string: String) async throws -> [InventoryThingEntity] {
        await MainActor.run {
            let key = InventoryMath.normalizedLookupKey(string)
            guard key.isEmpty == false else { return IntentInventoryData.thingEntities() }
            return IntentInventoryData.thingEntities().filter {
                InventoryMath.normalizedLookupKey($0.name).contains(key)
            }
        }
    }

    func suggestedEntities() async throws -> [InventoryThingEntity] {
        await MainActor.run {
            IntentInventoryData.thingEntities()
        }
    }
}

struct CountFurnitureIntent: AppIntent {
    static let title: LocalizedStringResource = "How Many Furniture"
    static let description = IntentDescription(
        "Returns the number of furniture entries.",
        categoryName: "Inventory"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = await MainActor.run { IntentInventoryData.digests().count }
        let dialog: LocalizedStringResource = "You currently have \(count) furniture entries."
        return .result(dialog: IntentDialog(dialog))
    }
}

struct CountThingsIntent: AppIntent {
    static let title: LocalizedStringResource = "How Many Things"
    static let description = IntentDescription(
        "Returns the total quantity of things.",
        categoryName: "Inventory"
    )

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let total = await MainActor.run {
            IntentInventoryData.digests()
                .flatMap(\.things)
                .reduce(0) { $0 + max(0, $1.quantity) }
        }
        let dialog: LocalizedStringResource = "You currently have \(total) things in total."
        return .result(dialog: IntentDialog(dialog))
    }
}

struct FurnitureContentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Furniture Contents"
    static let description = IntentDescription(
        "Returns the content of a furniture entry by name.",
        categoryName: "Inventory"
    )

    @Parameter(
        title: "Furniture Name",
        requestValueDialog: IntentDialog("Which furniture?")
    )
    var furnitureName: InventoryFurnitureEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = await MainActor.run {
            let match = IntentInventoryData.digests().first {
                $0.name.localizedCaseInsensitiveCompare(furnitureName.name) == .orderedSame
            }

            guard let match else {
                return L10n.Intents.noFurnitureFound(named: furnitureName.name)
            }

            if match.things.isEmpty {
                return L10n.Intents.furnitureEmpty(match.name)
            }

            let lines = match.things
                .map { L10n.Inventory.namedCount($0.name, count: $0.quantity) }
                .joined(separator: ", ")

            return L10n.Intents.furnitureContains(name: match.name, contents: lines)
        }

        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

struct FurnituresContainingThingIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Furniture by Thing"
    static let description = IntentDescription(
        "Returns furniture entries containing a given thing.",
        categoryName: "Inventory"
    )

    @Parameter(
        title: "Thing Name",
        requestValueDialog: IntentDialog("Which thing?")
    )
    var thingName: InventoryThingEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let response = await MainActor.run {
            let matches = IntentInventoryData.digests().compactMap { furniture -> String? in
                guard let thing = furniture.things.first(where: {
                    $0.name.localizedCaseInsensitiveCompare(thingName.name) == .orderedSame
                }) else {
                    return nil
                }
                return L10n.Inventory.namedCount(furniture.name, count: thing.quantity)
            }

            guard !matches.isEmpty else {
                return L10n.Intents.noFurnitureContains(thingName.name)
            }

            return matches.joined(separator: ", ")
        }

        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Open intents (Spotlight deep-link)

/// Cross-process navigation request (e.g. a Spotlight deep-link). Observed by
/// the home view, which switches section and scrolls to the named item. Using
/// an observable (rather than only a notification) makes it survive a cold
/// launch: the view applies the pending request when it appears, too.
@MainActor
final class InventoryNavigation: ObservableObject {
    static let shared = InventoryNavigation()

    struct Request: Equatable {
        let section: InventorySection
        let itemName: String
    }

    @Published var request: Request?

    private init() {}
}

/// Run by the system when a furniture entity is opened from Spotlight: brings
/// the app to the furniture section and scrolls to that furniture.
struct OpenFurnitureIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Furniture"

    @Parameter(title: "Furniture")
    var target: InventoryFurnitureEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        InventoryNavigation.shared.request = .init(section: .furniture, itemName: target.name)
        return .result()
    }
}

/// Run by the system when a thing entity is opened from Spotlight: brings the
/// app to the things section and scrolls to that thing.
struct OpenThingIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Thing"

    @Parameter(title: "Thing")
    var target: InventoryThingEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        InventoryNavigation.shared.request = .init(section: .things, itemName: target.name)
        return .result()
    }
}
