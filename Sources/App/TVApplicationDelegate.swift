import UIKit

final class TVApplicationDelegate: NSObject, UIApplicationDelegate {
    func applicationWillResignActive(_ application: UIApplication) {
        Task { @MainActor in
            InventorySnapshotPublisher.publishTopShelfFromPersistentStore()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { @MainActor in
            InventorySnapshotPublisher.publishTopShelfFromPersistentStore()
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            InventorySnapshotPublisher.publishTopShelfFromPersistentStore()
            completionHandler(.newData)
        }
    }
}
