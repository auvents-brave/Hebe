import Foundation
import SwiftData

enum PersistenceController {
    static let shared: ModelContainer = {
        do {
            return try makeBestAvailableContainer()
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }()

    static func makeBestAvailableContainer(preferCloudKit: Bool = true) throws -> ModelContainer {
        if preferCloudKit {
            do {
                return try makeContainer(useCloudKit: true)
            } catch {
                #if DEBUG
                    print("Falling back to local-only ModelContainer: \(error.localizedDescription)")
                #endif
            }
        }

        return try makeContainer(useCloudKit: false)
    }

    static func makeContainer(useCloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([
            Furniture.self,
            Thing.self,
            FurnitureThing.self,
        ])
        let storeURL = try storeURL()
        let configuration = useCloudKit
            ? ModelConfiguration("Hebe", url: storeURL, cloudKitDatabase: .automatic)
            : ModelConfiguration("Hebe", url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func storeURL() throws -> URL {
        #if os(tvOS)
            // On physical tvOS, files need an appropriate protection class to be
            // reachable. Use the caches directory with the right protection.
            let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!

            // Create a sub-directory for our store.
            let storeDirectory = documentsURL.appendingPathComponent("HebeData", isDirectory: true)

            // Create the directory with protection attributes suitable for tvOS.
            let attributes: [FileAttributeKey: Any] = [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ]
            
            if !FileManager.default.fileExists(atPath: storeDirectory.path) {
                try FileManager.default.createDirectory(
                    at: storeDirectory,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
            }
            
            let storeURL = storeDirectory.appendingPathComponent("Hebe.store")
            
            #if DEBUG
            print("=== tvOS Store URL ===")
            print("Store directory: \(storeDirectory.path)")
            print("Store URL: \(storeURL.path)")
            #endif
            
            return storeURL
        #else
            // On iOS, macOS, etc., use the App Group to share the store between the app and its extensions.
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            
            let appSupportURL = containerURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            return appSupportURL.appendingPathComponent("Hebe.store")
        #endif
    }
}
