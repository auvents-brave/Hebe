import SwiftUI
import UniformTypeIdentifiers

struct FurnitureTreeListView: View {
	private let digests: [FurnitureDigest]
	/// Selected furniture keys (top-level rows). Unused on tvOS/watchOS.
	@Binding private var selection: Set<String>
	/// Deletes a single furniture (swipe action).
	private let onDelete: (FurnitureDigest) -> Void

	/// Furniture digests keyed by their tree-node id, for drag export.
	private var digestsByID: [String: FurnitureDigest] {
		Dictionary(
			digests.map { (InventoryMath.normalizedLookupKey($0.name), $0) },
			uniquingKeysWith: { first, _ in first }
		)
	}

	init(
		digests: [FurnitureDigest],
		selection: Binding<Set<String>> = .constant([]),
		onDelete: @escaping (FurnitureDigest) -> Void = { _ in }
	) {
		self.digests = InventoryMath.normalizedDigests(digests)
		self._selection = selection
		self.onDelete = onDelete
	}

	init(
		furnitures: [Furniture],
		selection: Binding<Set<String>> = .constant([]),
		onDelete: @escaping (FurnitureDigest) -> Void = { _ in }
	) {
		let digests = furnitures.map { furniture in
			let things = (furniture.slots ?? [])
				.compactMap { slot -> ThingDigest? in
					guard let thing = slot.thing else { return nil }
					return ThingDigest(name: thing.name, quantity: slot.quantity)
				}
			return FurnitureDigest(name: furniture.name, things: things)
		}

		self.init(digests: digests, selection: selection, onDelete: onDelete)
	}

	private var nodes: [InventoryTreeNode] {
		digests.map { furniture in
			let children = furniture.things.map { thing in
				InventoryTreeNode(
					id:
						"\(InventoryMath.normalizedLookupKey(furniture.name))::\(InventoryMath.normalizedLookupKey(thing.name))",
					title: thing.name,
					detail: "\(thing.quantity)",
					children: nil
				)
			}

			return InventoryTreeNode(
				id: InventoryMath.normalizedLookupKey(furniture.name),
				title: furniture.name,
				detail: "\(children.count)",
				children: children
			)
		}
	}

	var body: some View {
		if nodes.isEmpty {
			ContentUnavailableView(
				String(localized: "No furniture yet"),
				systemImage: InventorySection.furniture.systemImage
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
			.accessibilityIdentifier("furniture_tree_list")
		} else {
			#if os(tvOS) || os(watchOS)
				List {
					ForEach(nodes) { node in
						#if os(tvOS)
							FocusHighlightRow { furnitureNodeContent(node) }
								.listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
						#else
							Button {
							} label: {
								furnitureNodeContent(node)
							}
							.buttonStyle(.plain)
						#endif
					}
				}
				.listStyle(.plain)
				#if os(tvOS)
					.focusSection()
				#endif
				.accessibilityIdentifier("furniture_tree_list")
			#else
				List(selection: $selection) {
					OutlineGroup(nodes, children: \.children) { node in
						if let digest = digestsByID[node.id] {
							// Top-level furniture: selectable, draggable, with row
							// actions (swipe on touch platforms, context menu on macOS).
							furnitureRow(node)
								.draggable(ExportedFurniture(digest: digest))
								.contextMenu { rowActions(digest: digest, name: node.title) }
								#if !os(macOS)
									.swipeActions(edge: .trailing) {
										rowActions(digest: digest, name: node.title)
									}
								#endif
						} else {
							// Inner thing: shown but not individually selectable.
							childRow(node)
								.selectionDisabled()
						}
					}
				}
				.listStyle(.plain)
				.accessibilityIdentifier("furniture_tree_list")
			#endif
		}
	}

	#if !os(tvOS) && !os(watchOS)
		@ViewBuilder
		private func rowActions(digest: FurnitureDigest, name: String) -> some View {
			Button(role: .destructive) {
				onDelete(digest)
			} label: {
				Label(String(localized: "Delete"), systemImage: "trash")
			}
			ShareLink(item: ExportedFurniture(digest: digest), preview: SharePreview(name)) {
				Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
			}
			.tint(.blue)
		}
	#endif

	#if os(tvOS) || os(watchOS)
		@ViewBuilder
		private func furnitureNodeContent(_ node: InventoryTreeNode) -> some View {
			VStack(alignment: .leading, spacing: 6) {
				furnitureRow(node)
				if let children = node.children, !children.isEmpty {
					ForEach(children) { child in
						childRow(child)
					}
				}
			}
		}
	#endif

	private func furnitureRow(_ node: InventoryTreeNode) -> some View {
		HStack {
			Text(node.title)
			Spacer()
			if let detail = node.detail {
				Text(detail)
					.foregroundStyle(.secondary)
					.monospacedDigit()
			}
		}
	}

	private func childRow(_ node: InventoryTreeNode) -> some View {
		HStack {
			Text(node.title)
			Spacer()
			if let detail = node.detail {
				Text(detail)
					.foregroundStyle(.secondary)
					.monospacedDigit()
			}
		}
		.padding(.leading, 12)
	}
}

#if !os(tvOS) && !os(watchOS)
	/// A single furniture, draggable out as an `.xml` file (the XML is produced
	/// lazily, only when the drag is actually performed).
	private struct ExportedFurniture: Transferable {
		let digest: FurnitureDigest

		static var transferRepresentation: some TransferRepresentation {
			DataRepresentation(exportedContentType: .xml) { exported in
				InventoryTransfer.xmlData(from: [exported.digest])
			}
			.suggestedFileName { "\($0.digest.name).xml" }
		}
	}
#endif
