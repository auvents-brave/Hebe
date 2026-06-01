import Foundation
import SwiftData
import UniformTypeIdentifiers
#if canImport(WidgetKit)
    import WidgetKit
#endif

enum ShareImportError: LocalizedError {
    case missingContext
    case importFailed

    var errorDescription: String? {
        switch self {
        case .missingContext:
            return String(localized: "Missing context for import")
        case .importFailed:
            return String(localized: "Import failed")
        }
    }
}

enum ShareImportSchema {
    static let exampleXML = String(localized: "Import furniture and items from XML files")
}

@MainActor
enum SharedInventoryStoreImporter {
    static func importDigests(_ digests: [FurnitureDigest]) async throws -> Bool {
        let normalizedDigests = InventoryMath.normalizedDigests(digests)
        guard normalizedDigests.isEmpty == false else {
            return false
        }

        // Write locally (no CloudKit). The extension must NOT spin up its own
        // CloudKit mirroring delegate on the shared store — two delegates on the
        // same store trigger a sync reset that invalidates the app's live objects
        // (and crashes it). The app keeps CloudKit and mirrors these writes.
        let container = try PersistenceController.makeContainer(useCloudKit: false)
        try InventoryRepository.mergeInventory(with: normalizedDigests, in: container.mainContext)

        // Republish snapshot if available (may not be available in extension targets)
        guard let snapshot = try? InventoryRepository.snapshot(in: container.mainContext) else {
            return true
        }

        InventorySnapshotStore.save(snapshot)

        #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: SharedConstants.widgetKind)
        #endif

        return true
    }
}

@MainActor
enum SharedInventoryImportLoader {
    static func loadDigests(from inputItems: [Any]) async -> [FurnitureDigest] {
        let providers = inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        var collected: [FurnitureDigest] = []
        for provider in providers {
            collected.append(contentsOf: await loadDigests(from: provider))
        }

        return InventoryMath.normalizedDigests(collected)
    }

    private static func loadDigests(from provider: NSItemProvider) async -> [FurnitureDigest] {
        var collected: [FurnitureDigest] = []

        if let fileURL = try? await provider.loadBestEffortFileURL() {
            collected = InventoryTransfer.digests(fromFileAt: fileURL)
        }

        if collected.isEmpty {
            let importableTypeIdentifiers = provider.registeredTypeIdentifiers.filter { identifier in
                guard let type = UTType(identifier) else { return false }
                return type.conforms(to: .xml) || type.conforms(to: .zip)
            }

            for typeIdentifier in importableTypeIdentifiers {
                guard let data = try? await provider.loadBestEffortData(forTypeIdentifier: typeIdentifier) else {
                    continue
                }
                collected.append(contentsOf: InventoryTransfer.digests(fromData: data, suggestedName: provider.suggestedName))
            }
        }

        return InventoryMath.normalizedDigests(collected)
    }
}

@MainActor
private extension NSItemProvider {
    func loadBestEffortData(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        if let data = try? await loadDataRepresentationAsync(forTypeIdentifier: typeIdentifier),
           !data.isEmpty {
            return data
        }

        if let data = try? await loadFileRepresentationData(forTypeIdentifier: typeIdentifier),
           !data.isEmpty {
            return data
        }

        throw CocoaError(.fileReadUnknown)
    }

    func loadDataRepresentationAsync(forTypeIdentifier typeIdentifier: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                guard let data else {
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: nil)
                    }
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    func loadFileRepresentationData(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    return
                }

                do {
                    continuation.resume(returning: try Data(contentsOf: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func loadBestEffortFileURL() async throws -> URL? {
        guard hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                do {
                    guard let url = (item as? URL) ?? (item as? NSURL as URL?) ??
                        (item as? String).flatMap({ URL(string: $0) }) else {
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: nil)
                        }
                        return
                    }

                    continuation.resume(returning: try persistSharedFileRepresentation(at: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private func persistSharedFileRepresentation(at sourceURL: URL) throws -> URL {
    let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if didStartAccessing {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(sourceURL.pathExtension)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
        try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
}
