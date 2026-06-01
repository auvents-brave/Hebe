import Foundation
import SwiftData

#if canImport(TVServices)
    import TVServices
#endif

@MainActor
enum InventorySnapshotPublisher {
    static func publish(context: ModelContext) {
        // Read on a fresh context bound to the same container. The passed context
        // may hold objects invalidated by an external write (e.g. an import from
        // the share extension); a fresh context fetches the current committed data
        // and avoids "backing data could no longer be found" crashes.
        let readContext = ModelContext(context.container)
        let snapshot = try? InventoryRepository.snapshot(in: readContext)
        if let snapshot {
            InventorySnapshotRepublisher.publish(snapshot: snapshot)
        }

        #if os(tvOS)
            if let snapshot {
                publishTopShelf(snapshot: snapshot)
            } else {
                requestTopShelfRefresh()
            }
        #endif

        guard let snapshot else { return }

        #if os(iOS) || os(macOS) || os(visionOS)
            SpotlightIndexer.reindex(using: snapshot, context: readContext)
        #endif

        #if canImport(ActivityKit)
            LiveBubbleManager.shared.update(with: snapshot)
        #endif
    }

    #if os(tvOS)
        static func publishTopShelf(snapshot: InventorySnapshot) {
            InventorySnapshotStore.save(snapshot)
            recordEmbeddedTopShelfPluginState()
            TopShelfDiagnosticsStore.recordAppPublish(snapshot: snapshot)
            TopShelfDiagnosticsStore.recordTopShelfChangeRequested()
            TVTopShelfContentProvider.topShelfContentDidChange()
        }

        static func requestTopShelfRefresh() {
            recordEmbeddedTopShelfPluginState()
            TopShelfDiagnosticsStore.recordTopShelfChangeRequested()
            TVTopShelfContentProvider.topShelfContentDidChange()
        }

        static func publishTopShelfFromPersistentStore() {
            if let container = try? PersistenceController.makeContainer(useCloudKit: false) {
                let context = ModelContext(container)
                if let snapshot = try? InventoryRepository.snapshot(in: context) {
                    InventoryCountNotificationPublisher.evaluate(snapshot: snapshot)
                    publishTopShelf(snapshot: snapshot)
                    return
                }
            }

            requestTopShelfRefresh()
        }

        private static func recordEmbeddedTopShelfPluginState() {
            let pluginURLs: [URL]
            if let builtInPlugInsURL = Bundle.main.builtInPlugInsURL,
               let contents = try? FileManager.default.contentsOfDirectory(
                   at: builtInPlugInsURL,
                   includingPropertiesForKeys: nil
               ) {
                pluginURLs = contents.filter { $0.pathExtension == "appex" }
            } else {
                pluginURLs = []
            }

            let fileNames: [String] = pluginURLs.map(\.lastPathComponent)
            let bundleIdentifiers: [String] = pluginURLs.compactMap { url -> String? in
                Bundle(url: url)?.bundleIdentifier
            }
            let extensionPoints: [String] = pluginURLs.compactMap { url -> String? in
                guard let info = Bundle(url: url)?.infoDictionary,
                      let extensionDict = info["NSExtension"] as? [String: Any]
                else { return nil }
                return extensionDict["NSExtensionPointIdentifier"] as? String
            }
            let principalClasses: [String] = pluginURLs.compactMap { url -> String? in
                guard let info = Bundle(url: url)?.infoDictionary,
                      let extensionDict = info["NSExtension"] as? [String: Any]
                else { return nil }
                return extensionDict["NSExtensionPrincipalClass"] as? String
            }

            TopShelfDiagnosticsStore.recordEmbeddedPluginScan(
                bundleIdentifiers: bundleIdentifiers,
                fileNames: fileNames,
                extensionPoints: extensionPoints,
                principalClasses: principalClasses
            )
        }
    #endif
}
