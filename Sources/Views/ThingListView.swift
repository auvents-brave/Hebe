import SwiftUI
import UniformTypeIdentifiers

/// The flat list of distinct things, each shown with its per-furniture
/// occurrences. The counterpart to ``FurnitureTreeListView`` for the Things
/// section of ``InventoryHomeView``.
struct ThingListView: View {
    let things: [Thing]
    /// Selected thing names (Things section). Unused on tvOS/watchOS.
    @Binding var selection: Set<String>
    /// Deletes a single thing (swipe action).
    var onDelete: (Thing) -> Void = { _ in }

    var body: some View {
        if things.isEmpty {
            ContentUnavailableView(
                String(localized: "No things yet"),
                systemImage: InventorySection.things.systemImage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            #if os(tvOS) || os(watchOS)
                List {
                    ForEach(things) { thing in
                        #if os(tvOS)
                            FocusHighlightRow { row(thing) }
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        #else
                            Button {} label: { row(thing) }
                                .buttonStyle(.plain)
                        #endif
                    }
                }
                .listStyle(.plain)
                #if os(tvOS)
                    .focusSection()
                #endif
            #else
                List(selection: $selection) {
                    ForEach(things, id: \.name) { thing in
                        row(thing)
                            .contextMenu { rowActions(for: thing) }
                            #if !os(macOS)
                                .swipeActions(edge: .trailing) { rowActions(for: thing) }
                            #endif
                    }
                }
                .listStyle(.plain)
            #endif
        }
    }

    #if !os(tvOS) && !os(watchOS)
    @ViewBuilder
    private func rowActions(for thing: Thing) -> some View {
        Button(role: .destructive) { onDelete(thing) } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
        ShareLink(
            item: ExportedThing(fileName: "\(thing.name).xml", digests: digests(for: thing)),
            preview: SharePreview(thing.name)
        ) {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }
        .tint(.blue)
    }
    #endif

    /// The furnitures (with quantities) that contain `thing` — its occurrences.
    private func digests(for thing: Thing) -> [FurnitureDigest] {
        (thing.slots ?? []).compactMap { slot in
            guard let furnitureName = slot.furniture?.name else { return nil }
            return FurnitureDigest(name: furnitureName, things: [ThingDigest(name: thing.name, quantity: slot.quantity)])
        }
    }

    @ViewBuilder
    private func row(_ thing: Thing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(thing.name)
                .font(.headline)

            ForEach((thing.slots ?? []).compactMap({ slot -> (String, Int)? in
                guard let furnitureName = slot.furniture?.name else { return nil }
                return (furnitureName, slot.quantity)
            }), id: \.0) { entry in
                Text(L10n.Inventory.namedCount(entry.0, count: entry.1))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#if !os(tvOS) && !os(watchOS)
    /// A single thing and all its occurrences, shared out as an `.xml` file (the
    /// XML is produced lazily, only when the share is actually performed).
    private struct ExportedThing: Transferable {
        let fileName: String
        let digests: [FurnitureDigest]

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(exportedContentType: .xml) { exported in
                InventoryTransfer.xmlData(from: exported.digests)
            }
            .suggestedFileName { $0.fileName }
        }
    }
#endif

#Preview("Things List") { @MainActor in
    ThingListView(things: PreviewData.things(), selection: .constant([]))
}
