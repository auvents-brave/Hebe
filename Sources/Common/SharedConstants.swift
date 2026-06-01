import Foundation

enum SharedConstants {
    static let appGroupIdentifier = "group.com.lesvagabondages.waypoints"
    static let inventorySnapshotKey = "inventory_snapshot_v1"
    static let widgetKind = "HebeInventoryWidget"
}

extension Notification.Name {
    static let hebeTVUserDidChange = Notification.Name("HebeTVUserDidChange")
    static let persistentStoreRemoteChange = Notification.Name("NSPersistentStoreRemoteChangeNotification")
    static let hebeMacSharePreview = Notification.Name("HebeMacSharePreview")
}
