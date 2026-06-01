import Foundation

struct InventoryTreeNode: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let children: [InventoryTreeNode]?
}
