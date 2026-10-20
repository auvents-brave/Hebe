import Euryale
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppIntents)
	import AppIntents
#endif
#if canImport(UIKit)
	import UIKit
#endif
#if canImport(TVServices)
	import TVServices
#endif
#if os(macOS)
	import AppKit
#endif

struct InventoryHomeView: View {
	@Environment(\.modelContext) private var modelContext
	@Environment(\.scenePhase) private var scenePhase

	@Query(sort: \Furniture.name, order: .forward)
	private var furnitures: [Furniture]

	@Query(sort: \Thing.name, order: .forward)
	private var things: [Thing]

	@State private var selectedSection: InventorySection = .furniture
	@State private var isMutatingData = false
	@State private var showingDeleteConfirmation = false
	@State private var dataErrorMessage: String?
	@State private var showingSettings = false
	@State private var availableSize: CGSize = .zero
	@State private var showingImport = false
	@State private var xmlExportURL: URL?
	@State private var zipExportURL: URL?
	/// Selected row identifiers in the current section (furniture keys in the
	/// Furniture section, thing names in the Things section).
	@State private var selection = Set<String>()
	#if !os(watchOS)
		@ObservedObject private var navigation = InventoryNavigation.shared
	#endif

	let iCloudAvailable: Bool

	#if !os(watchOS)
		/// Applies a deep-link request by switching to the relevant section and
		/// selecting (highlighting) the target row.
		private func applyNavigation(_ request: InventoryNavigation.Request) {
			selectedSection = request.section
			let id =
				request.section == .furniture
				? InventoryMath.normalizedLookupKey(request.itemName)
				: request.itemName
			selection = [id]
			navigation.request = nil
		}
	#endif

	/// Whether the secondary stats pills (furniture, distinct things) are shown
	/// alongside the primary one. A row of pills is always short, so when the
	/// width fits one they stay. They only drop — keeping just the primary
	/// "things" pill — when the width is too tight (they'd stack) and height is
	/// scarce. On macOS the minimum window width keeps them on one row.
	private var showsSecondaryPills: Bool {
		guard availableSize.height > 0 else { return true }
		if availableSize.width >= 560 { return true }
		let stackedHeight = CGFloat(snapshot.stats.count) * 64
		return stackedHeight <= availableSize.height * 0.3
	}

	private var currentDigests: [FurnitureDigest] {
		furnitures.map { furniture in
			let things = (furniture.slots ?? []).compactMap { slot -> ThingDigest? in
				guard let name = slot.thing?.name else { return nil }
				return ThingDigest(name: name, quantity: slot.quantity)
			}
			return FurnitureDigest(name: furniture.name, things: things)
		}
	}

	private var snapshot: InventorySnapshot {
		InventoryMath.makeSnapshot(from: currentDigests)
	}

	/// Identifiers of every row in the current section (for "Select All").
	private var allCurrentIDs: Set<String> {
		switch selectedSection {
		case .furniture: Set(currentDigests.map { InventoryMath.normalizedLookupKey($0.name) })
		case .things: Set(things.map(\.name))
		}
	}

	/// Digests to export/share: the current selection, or everything when the
	/// selection is empty. In the Things section, a selected thing contributes
	/// all its occurrences (each containing furniture, filtered to that thing).
	private var selectedDigests: [FurnitureDigest] {
		guard selection.isEmpty == false else { return currentDigests }
		switch selectedSection {
		case .furniture:
			return currentDigests.filter { selection.contains(InventoryMath.normalizedLookupKey($0.name)) }
		case .things:
			return currentDigests.compactMap { furniture in
				let kept = furniture.things.filter { selection.contains($0.name) }
				return kept.isEmpty ? nil : FurnitureDigest(name: furniture.name, things: kept)
			}
		}
	}

	/// Base file name (without extension) for exports.
	private var exportBaseName: String { String(localized: "Hebe Inventory") }

	/// Regenerates the shareable XML and ZIP files (of the current selection,
	/// or everything) used by the toolbar Share menu.
	#if !os(tvOS) && !os(watchOS)
		private func regenerateExports() {
			let digests = selectedDigests
			xmlExportURL = InventoryTransfer.temporaryXMLURL(from: digests, fileName: "\(exportBaseName).xml")
			zipExportURL = InventoryTransfer.temporaryZipURL(from: digests, baseName: exportBaseName)
		}
	#endif

	private var dataFingerprint: Int {
		furnitures.reduce(0) { partial, furniture in
			partial
				^ furniture.id.hashValue
				^ (furniture.slots ?? []).reduce(0) { acc, slot in acc ^ slot.id.hashValue ^ slot.quantity.hashValue }
		}
			^ things.reduce(0) { $0 ^ $1.id.hashValue }
	}

	/// Leading radio-style section switcher, then a divider, then the commands.
	private var toolbarGroups: [[ToolbarAction]] {
		let sections: [ToolbarAction] = InventorySection.allCases.map { section in
			ToolbarAction(
				id: "section.\(section.id)",
				title: section.title,
				systemImage: section.systemImage,
				isSelected: selectedSection == section,
				canOverflow: false
			) {
				selectedSection = section
				selection = []
			}
		}
		// In the macOS title bar, keep command buttons icon-only (the radio
		// group stays labelled) so the whole row fits without overflowing into
		// the native `»`. Elsewhere they adapt label↔icon with width.
		#if os(macOS)
			let commandDisplay: ToolbarAction.LabelDisplay = .iconOnly
		#else
			let commandDisplay: ToolbarAction.LabelDisplay = .adaptive
		#endif
		var commands: [ToolbarAction] = []
		// Select All — macOS uses the standard Edit ▸ Select All (⌘A); the other
		// platforms get a toolbar button.
		#if !os(tvOS) && !os(watchOS) && !os(macOS)
			commands.append(
				ToolbarAction(
					title: String(localized: "Select All"),
					systemImage: "checklist",
					display: commandDisplay,
					isEnabled: !allCurrentIDs.isEmpty
				) { selectAll() }
			)
		#endif
		// Share the inventory: a menu offering XML or ZIP (each a ShareLink, so
		// no chooser sheet lingers). Disabled when empty. No ShareLink on tvOS/watchOS.
		#if !os(tvOS) && !os(watchOS)
			if let xmlExportURL, let zipExportURL {
				commands.append(
					ToolbarAction(
						title: String(localized: "Share"),
						systemImage: "square.and.arrow.up",
						display: commandDisplay,
						isEnabled: !furnitures.isEmpty,
						shareItems: [
							ToolbarShareItem(
								title: String(localized: "XML file"), systemImage: "doc.text", url: xmlExportURL),
							ToolbarShareItem(
								title: String(localized: "ZIP archive"), systemImage: "doc.zipper", url: zipExportURL),
						]
					) {}
				)
			}
		#endif
		commands.append(contentsOf: [
			ToolbarAction(
				title: String(localized: "Delete All"),
				systemImage: "trash",
				display: commandDisplay,
				role: .destructive,
				isEnabled: !isMutatingData && !furnitures.isEmpty
			) { showingDeleteConfirmation = true },
			ToolbarAction(
				title: String(localized: "Fill Random"),
				systemImage: "wand.and.stars",
				display: commandDisplay,
				isEnabled: !isMutatingData
			) { fillRandomData() },
		])
		// macOS opens Settings from the app menu (⌘,), so no toolbar button there.
		#if !os(macOS)
			commands.append(
				ToolbarAction(
					title: String(localized: "Settings"),
					systemImage: "gearshape",
					display: commandDisplay,
					opensSettings: true
				) { showingSettings = true }
			)
		#endif
		return [sections, commands]
	}

	#if !os(watchOS)
		@ViewBuilder
		private var sectionList: some View {
			Group {
				if selectedSection == .furniture {
					FurnitureTreeListView(
						furnitures: furnitures,
						selection: $selection,
						onDelete: { digest in deleteFurniture(digest) }
					)
				} else {
					ThingListView(
						things: things,
						selection: $selection,
						onDelete: { thing in deleteThing(thing) }
					)
				}
			}
			#if os(tvOS)
				.padding(.top, 6)
			#endif
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	#endif

	var body: some View {
		NavigationStack {
			VStack(spacing: 8) {
				// tvOS keeps the bar inline at the top (no overlay); the other
				// platforms float it at the bottom via `safeAreaInset` below.
				#if os(tvOS)
					AdaptiveToolbar(groups: toolbarGroups)
						.focusSection()
						.padding(.bottom, 16)
				#endif

				InventoryStatsView(snapshot: snapshot, showsSecondary: showsSecondaryPills)
					#if os(iOS) && !targetEnvironment(macCatalyst)
						.padding(.horizontal)
					#endif

				#if !os(tvOS) && !os(watchOS)
					InventorySectionSiriTipView(section: selectedSection)
						.padding(.horizontal)
				#endif

				#if os(watchOS)
					Button {
						showingSettings = true
					} label: {
						Label(String(localized: "Settings"), systemImage: "gearshape")
					}
					.accessibilityIdentifier("settings_button")
					.frame(maxWidth: .infinity, alignment: .leading)
				#endif

				#if !os(watchOS)
					sectionList
				#endif
			}
			.padding(.top, 8)
			#if os(iOS) && !targetEnvironment(macCatalyst)
				.padding(.bottom, 0)
			#else
				.padding(.horizontal)
				.padding(.bottom, 4)
			#endif
			#if os(iOS)
				.navigationBarTitleDisplayMode(.inline)
			#endif
			// Floating, centred glass toolbar at the bottom; the list scrolls
			// underneath it. macOS uses the native window toolbar (below); tvOS
			// uses the inline top bar instead.
			#if !os(tvOS) && !os(watchOS) && !os(macOS)
				.safeAreaInset(edge: .bottom) {
					AdaptiveToolbar(groups: toolbarGroups)
					.padding(.horizontal)
					.padding(.bottom, 6)
					.frame(maxWidth: .infinity, alignment: .center)
				}
			#endif
			#if os(macOS)
				// Xcode-style title bar: big title + section subtitle, with the
				// toolbar pinned trailing. A native toolbar item can't feed real
				// width to `ViewThatFits`, so keep labels (no icon collapse) and no
				// overflow `…` (a popover/menu from a toolbar item is unreliable).
				.navigationTitle(String(localized: "Hebe Inventory"))
				.navigationSubtitle(selectedSection.title)
				.toolbar {
					ToolbarItem(placement: .primaryAction) {
						AdaptiveToolbar(
							groups: toolbarGroups,
							showsBackground: false,
							allowsOverflow: false,
							collapsesToIcons: false
						)
					}
				}
			#endif
		}
		.background {
			// Measures the available size to decide how many stats pills fit
			// (see `showsSecondaryPills`). A background read doesn't affect layout
			// and doesn't reserve space, unlike constraining the pills' frame.
			GeometryReader { proxy in
				Color.clear
					.onChange(of: proxy.size, initial: true) { _, size in
						availableSize = size
					}
			}
		}
		.onAppear {
			InventorySnapshotPublisher.publish(context: modelContext)
			#if !os(tvOS) && !os(watchOS)
				regenerateExports()
			#endif
			// Apply a deep-link that arrived before the view was observing
			// (e.g. a cold launch from Spotlight).
			#if !os(watchOS)
				if let request = navigation.request { applyNavigation(request) }
			#endif
		}
		#if !os(watchOS)
			.onChange(of: navigation.request) { _, request in
				if let request { applyNavigation(request) }
			}
		#endif
		.onChange(of: dataFingerprint) { _, _ in
			InventorySnapshotPublisher.publish(context: modelContext)
			#if !os(tvOS) && !os(watchOS)
				regenerateExports()
			#endif
		}
		#if !os(tvOS) && !os(watchOS)
			// Share exports the current selection, so refresh the files when it changes.
			.onChange(of: selection) { _, _ in regenerateExports() }
			.onChange(of: selectedSection) { _, _ in regenerateExports() }
		#endif
		.onReceive(NotificationCenter.default.publisher(for: .hebeTVUserDidChange).receive(on: RunLoop.main)) { _ in
			InventorySnapshotPublisher.publish(context: modelContext)
		}
		.onReceive(NotificationCenter.default.publisher(for: .hebeQuickAction).receive(on: RunLoop.main)) { note in
			if let section = note.object as? InventorySection {
				selectedSection = section
				selection = []
			}
		}
		.task {
			QuickActions.performPendingLaunchAction()
		}
		.onChange(of: scenePhase) { _, newPhase in
			guard newPhase == .inactive || newPhase == .background else { return }
			#if os(tvOS)
				InventorySnapshotPublisher.publishTopShelf(snapshot: snapshot)
			#else
				InventorySnapshotPublisher.publish(context: modelContext)
			#endif
		}
		.onReceive(NotificationCenter.default.publisher(for: .persistentStoreRemoteChange).receive(on: RunLoop.main)) {
			_ in
			InventorySnapshotPublisher.publish(context: modelContext)
		}
		#if os(tvOS)
			.onReceive(
				NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification).receive(
					on: RunLoop.main)
			) { _ in
				InventorySnapshotPublisher.publishTopShelf(snapshot: snapshot)
			}
		#endif
		#if !os(macOS)
			.toolbar(.visible, for: .navigationBar)
			// macOS uses the standard Settings window instead of a sheet.
			.sheet(isPresented: $showingSettings) {
				SettingsView()
			}
		#endif
		#if !os(tvOS) && !os(watchOS)
			.fileImporter(isPresented: $showingImport, allowedContentTypes: [.xml, .zip]) { result in
				importInventory(from: result)
			}
			// Drop an XML/ZIP file anywhere in the window to import it.
			.dropDestination(for: URL.self) { urls, _ in
				guard let url = urls.first else { return false }
				importInventory(fromFileAt: url)
				return true
			}
		#endif
		#if os(macOS)
			// Standard menu commands (File ▸ Import…/Export…, Edit ▸ Select All,
			// Inventory ▸ …) routed from HebeApp. Extracted to keep `body` light.
			.modifier(
				MacInventoryCommands(
					isEmpty: furnitures.isEmpty,
					onImport: { showingImport = true },
					onExport: { InventoryExportPanel.run(digests: selectedDigests, baseName: exportBaseName) },
					onFill: { fillRandomData() },
					onDelete: { showingDeleteConfirmation = true }
				))
		#endif
		#if os(tvOS)
			.alert(String(localized: "Delete all data?"), isPresented: $showingDeleteConfirmation) {
				Button(String(localized: "Delete All"), role: .destructive) {
					deleteAllData()
				}
				Button(String(localized: "Cancel"), role: .cancel) {}
			}
		#else
			.confirmationDialog(
				deleteConfirmationTitle,
				isPresented: $showingDeleteConfirmation,
				titleVisibility: .visible
			) {
				Button(
					selection.isEmpty ? String(localized: "Delete All") : String(localized: "Delete"),
					role: .destructive
				) {
					performDelete()
				}
				Button(String(localized: "Cancel"), role: .cancel) {}
			}
		#endif
		.alert(
			String(localized: "Action Failed"),
			isPresented: Binding(
				get: { dataErrorMessage != nil },
				set: { _ in dataErrorMessage = nil }
			)
		) {
			Button(String(localized: "OK"), role: .cancel) {}
		} message: {
			Text(dataErrorMessage ?? String(localized: "Unknown error."))
		}
	}

	private func deleteAllData() {
		isMutatingData = true
		defer { isMutatingData = false }
		do {
			try InventoryRepository.deleteAll(in: modelContext)
			InventorySnapshotPublisher.publish(context: modelContext)
		} catch {
			dataErrorMessage = error.localizedDescription
		}
	}

	/// Confirmation title reflecting the current selection (all / one named / N).
	private var deleteConfirmationTitle: String {
		if selection.isEmpty { return String(localized: "Delete all data?") }
		if selection.count == 1, let name = singleSelectionDisplayName {
			return String(localized: "Delete \(name)?")
		}
		return String(localized: "Delete \(selection.count) items?")
	}

	private var singleSelectionDisplayName: String? {
		guard selection.count == 1, let id = selection.first else { return nil }
		switch selectedSection {
		case .furniture: return currentDigests.first { InventoryMath.normalizedLookupKey($0.name) == id }?.name
		case .things: return id
		}
	}

	#if !os(tvOS) && !os(watchOS)
		private func selectAll() { selection = allCurrentIDs }
	#endif

	/// Deletes the current selection, or everything when nothing is selected.
	private func performDelete() {
		isMutatingData = true
		defer { isMutatingData = false }
		do {
			if selection.isEmpty {
				try InventoryRepository.deleteAll(in: modelContext)
			} else {
				switch selectedSection {
				case .furniture:
					try InventoryRepository.deleteFurnitures(matchingKeys: selection, in: modelContext)
				case .things:
					try InventoryRepository.deleteThings(named: selection, in: modelContext)
				}
				selection = []
			}
			InventorySnapshotPublisher.publish(context: modelContext)
		} catch {
			dataErrorMessage = error.localizedDescription
		}
	}

	/// Deletes a single furniture (swipe action). Clears it from the selection too.
	private func deleteFurniture(_ digest: FurnitureDigest) {
		let key = InventoryMath.normalizedLookupKey(digest.name)
		isMutatingData = true
		defer { isMutatingData = false }
		do {
			try InventoryRepository.deleteFurnitures(matchingKeys: [key], in: modelContext)
			selection.remove(key)
			InventorySnapshotPublisher.publish(context: modelContext)
		} catch {
			dataErrorMessage = error.localizedDescription
		}
	}

	/// Deletes a single thing everywhere (swipe action). Clears it from the selection too.
	private func deleteThing(_ thing: Thing) {
		let name = thing.name
		isMutatingData = true
		defer { isMutatingData = false }
		do {
			try InventoryRepository.deleteThings(named: [name], in: modelContext)
			selection.remove(name)
			InventorySnapshotPublisher.publish(context: modelContext)
		} catch {
			dataErrorMessage = error.localizedDescription
		}
	}

	private func fillRandomData() {
		isMutatingData = true
		defer { isMutatingData = false }
		do {
			try InventoryRepository.fillRandomData(in: modelContext)
			InventorySnapshotPublisher.publish(context: modelContext)
		} catch {
			dataErrorMessage = error.localizedDescription
		}
	}

	/// Imports furniture/things from a chosen XML or ZIP file, merging into the
	/// current store.
	#if !os(tvOS) && !os(watchOS)
		private func importInventory(from result: Result<URL, Error>) {
			if case .success(let url) = result {
				importInventory(fromFileAt: url)
			}
		}

		/// Parses an XML/ZIP file and merges it into the store (used by the file
		/// importer and by drag-and-drop).
		private func importInventory(fromFileAt url: URL) {
			let didAccess = url.startAccessingSecurityScopedResource()
			defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

			let digests = InventoryTransfer.digests(fromFileAt: url)
			guard digests.isEmpty == false else {
				dataErrorMessage = String(localized: "Nothing to import")
				return
			}

			isMutatingData = true
			defer { isMutatingData = false }
			do {
				try InventoryRepository.mergeInventory(with: digests, in: modelContext)
				InventorySnapshotPublisher.publish(context: modelContext)
			} catch {
				dataErrorMessage = error.localizedDescription
			}
		}
	#endif

}

#if os(macOS)
	/// Wires the macOS menu commands (posted as notifications by `HebeApp`) to
	/// the home view's actions. Kept as a modifier so `body` stays type-checkable.
	private struct MacInventoryCommands: ViewModifier {
		let isEmpty: Bool
		let onImport: () -> Void
		let onExport: () -> Void
		let onFill: () -> Void
		let onDelete: () -> Void

		func body(content: Content) -> some View {
			content
				.onReceive(NotificationCenter.default.publisher(for: .hebeImportRequested)) { _ in onImport() }
				.onReceive(NotificationCenter.default.publisher(for: .hebeExportRequested)) { _ in onExport() }
				.onReceive(NotificationCenter.default.publisher(for: .hebeFillRandomRequested)) { _ in onFill() }
				.onReceive(NotificationCenter.default.publisher(for: .hebeDeleteAllRequested)) { _ in onDelete() }
				.onChange(of: isEmpty, initial: true) { _, empty in
					InventoryMenuState.shared.canExport = !empty
				}
		}
	}
#endif

/// Shared stats pills (icon + label + value) used by the main screen and the
/// macOS menu-bar popover, so both render identically.
struct InventoryStatsView: View {
	let snapshot: InventorySnapshot
	/// When `false`, only the primary "things" pill is shown.
	var showsSecondary: Bool = true

	var body: some View {
		let stats = showsSecondary ? snapshot.stats : snapshot.stats.filter { $0.kind == .things }
		PillsView(
			items: stats.map {
				PillsView.Item(label: $0.label, systemImage: $0.systemImage, value: $0.value)
			}
		)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

#if !os(tvOS) && !os(watchOS)
	private struct InventorySectionSiriTipView: View {
		let section: InventorySection

		@StateObject private var settingsStore = SettingsStore.shared

		var body: some View {
			switch section {
			case .furniture:
				RollingTipView(
					.init(CountFurnitureIntent(), $settingsStore.showSiriTip),
					.init(FurnitureContentsIntent(), $settingsStore.showSiriTip)
				)
			case .things:
				RollingTipView(
					.init(CountThingsIntent(), $settingsStore.showSiriTip),
					.init(FurnituresContainingThingIntent(), $settingsStore.showSiriTip)
				)
			}
		}
	}
#endif

#Preview("Inventory Home") { @MainActor in
	InventoryHomeView(iCloudAvailable: true)
		.modelContainer(PreviewData.container())
}

#Preview("Inventory Stats") { @MainActor in
	InventoryStatsView(snapshot: PreviewData.snapshot())
		.padding()
}

#Preview("Furniture List") { @MainActor in
	FurnitureTreeListView(furnitures: PreviewData.furnitures())
}

#if os(macOS)
	/// The macOS "Save As" panel for export, with a format popup (XML / ZIP) as
	/// an accessory view — the system save panel doesn't offer one for multiple
	/// content types, so we add it.
	@MainActor
	enum InventoryExportPanel {
		private static var retained: NSObject?

		static func run(digests: [FurnitureDigest], baseName: String) {
			let controller = Controller(digests: digests, baseName: baseName)
			retained = controller
			controller.present { retained = nil }
		}

		@MainActor
		private final class Controller: NSObject {
			private let digests: [FurnitureDigest]
			private let baseName: String
			private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
			private weak var panel: NSSavePanel?

			init(digests: [FurnitureDigest], baseName: String) {
				self.digests = digests
				self.baseName = baseName
				super.init()
			}

			func present(completion: @escaping () -> Void) {
				let panel = NSSavePanel()
				self.panel = panel
				panel.nameFieldStringValue = baseName
				panel.canCreateDirectories = true

				popup.addItems(withTitles: [String(localized: "XML file"), String(localized: "ZIP archive")])
				popup.target = self
				popup.action = #selector(formatChanged)
				let label = NSTextField(labelWithString: String(localized: "Format:"))
				let stack = NSStackView(views: [label, popup])
				stack.orientation = .horizontal
				stack.alignment = .centerY
				stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
				panel.accessoryView = stack
				applyFormat()

				panel.begin { [self] response in
					if response == .OK, let url = panel.url { write(to: url) }
					completion()
				}
			}

			private var isZIP: Bool { popup.indexOfSelectedItem == 1 }

			@objc private func formatChanged() { applyFormat() }

			private func applyFormat() {
				panel?.allowedContentTypes = isZIP ? [.zip] : [.xml]
			}

			private func write(to url: URL) {
				let data =
					isZIP
					? InventoryTransfer.zipData(from: digests, baseName: baseName)
					: InventoryTransfer.xmlData(from: digests)
				guard let data else { return }
				try? data.write(to: url, options: .atomic)
			}
		}
	}
#endif
