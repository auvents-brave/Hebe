import AppIntents
import Euryale
import SwiftData
import SwiftUI
import UserNotifications

#if os(iOS) || os(tvOS) || os(visionOS)
	import UIKit
#elseif os(macOS)
	import AppKit
#elseif os(watchOS)
	import WatchKit
#endif
#if os(iOS) || os(visionOS)
	import BackgroundTasks
#endif
#if canImport(WidgetKit)
	import WidgetKit
#endif

extension Notification.Name {
	/// Posted with the selected ``InventorySection`` when a quick action is picked.
	static let hebeQuickAction = Notification.Name("HebeQuickAction")
	#if os(macOS)
		/// Posted when the standard File ▸ Import… menu item is chosen.
		static let hebeImportRequested = Notification.Name("HebeImportRequested")
		/// Posted when the standard File ▸ Export… menu item is chosen.
		static let hebeExportRequested = Notification.Name("HebeExportRequested")
		/// Posted when the Inventory ▸ Fill Random menu item is chosen.
		static let hebeFillRandomRequested = Notification.Name("HebeFillRandomRequested")
		/// Posted when the Inventory ▸ Delete All menu item is chosen.
		static let hebeDeleteAllRequested = Notification.Name("HebeDeleteAllRequested")
	#endif
}

#if os(macOS)
	/// Shared state backing the enabled/disabled status of the macOS menu items.
	@MainActor
	final class InventoryMenuState: ObservableObject {
		static let shared = InventoryMenuState()
		/// Whether there is anything to export (drives File ▸ Export… enablement).
		@Published var canExport = false
		private init() {}
	}
#endif

@main
struct HebeApp: App {
	@State private var container: ModelContainer?
	@State private var containerErrorMessage: String?
	@State private var shouldSeedData = false
	@State private var shouldCheckCloudAvailability = true
	#if os(iOS)
		@UIApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var quickActionsDelegate
	#elseif os(macOS)
		@NSApplicationDelegateAdaptor(QuickActionsAppDelegate.self) private var quickActionsDelegate
		@StateObject private var settingsStore = SettingsStore.shared
		@StateObject private var menuState = InventoryMenuState.shared
		@State private var statusItemController: StatsStatusItemController?
	#elseif os(tvOS)
		@UIApplicationDelegateAdaptor(TVApplicationDelegate.self) private var tvApplicationDelegate
		@StateObject private var userMonitor = TVUserSessionMonitor()
	#endif
	#if os(iOS) || os(visionOS)
		@Environment(\.scenePhase) private var scenePhase
	#endif

	init() {
		Bundle.main.synchronizeDisplayedVersion()
		#if !os(watchOS)
			Task.detached(priority: .utility) {
				HebeAppShortcutsProvider.updateAppShortcutParameters()
			}
		#endif

		QuickActions.install([
			QuickAction(
				id: "section.furniture",
				title: InventorySection.furniture.title,
				systemImage: InventorySection.furniture.systemImage
			) { NotificationCenter.default.post(name: .hebeQuickAction, object: InventorySection.furniture) },
			QuickAction(
				id: "section.things",
				title: InventorySection.things.title,
				systemImage: InventorySection.things.systemImage
			) { NotificationCenter.default.post(name: .hebeQuickAction, object: InventorySection.things) },
		])
	}

	var body: some Scene {
		WindowGroup {
			Group {
				if let container {
					HebeRootContainerView(
						shouldSeedData: shouldSeedData,
						shouldCheckCloudAvailability: shouldCheckCloudAvailability,
						shouldWaitForRemoteData: shouldCheckCloudAvailability
					)
					.modelContainer(container)
				} else if let containerErrorMessage {
					VStack(spacing: 12) {
						Text(String(localized: "Unable to start"))
							.font(.headline)
						Text(containerErrorMessage)
							.font(.footnote)
							.multilineTextAlignment(.center)
							.foregroundStyle(.secondary)
					}
					.padding()
				} else {
					#if os(iOS)
						Color(.launchBackground).ignoresSafeArea()
					#else
						SplashScreenView()
					#endif
				}
			}
			.task {
				await beginBootstrapIfNeeded()
			}
			#if os(macOS)
				// Keep the window wide enough that the three stats pills always fit
				// on one row (their labels would otherwise wrap to two lines).
				.frame(minWidth: 560, minHeight: 360)
				.onAppear {
					updateStatusItemVisibility()
				}
				.onChange(of: settingsStore.showMenuBarStats) { _, _ in
					updateStatusItemVisibility()
				}
			#elseif os(tvOS)
				.onAppear {
					userMonitor.start()
				}
				.onReceive(NotificationCenter.default.publisher(for: .hebeTVUserDidChange)) { _ in
					Task { await reloadContainerForUserChange() }
				}
			#endif
			#if os(iOS) || os(visionOS)
				// Schedule a background refresh whenever the app is backgrounded, so
				// widgets stay current (picking up CloudKit changes) without launch.
				.onChange(of: scenePhase) { _, phase in
					if phase == .background { BackgroundRefresh.schedule() }
				}
			#endif
		}
		#if os(iOS) || os(visionOS)
			.backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
				await BackgroundRefresh.perform()
			}
		#endif
		#if os(macOS)
			.windowResizability(.contentMinSize)
			.commands {
				CommandGroup(replacing: .importExport) {
					Button(String(localized: "Import…")) {
						NotificationCenter.default.post(name: .hebeImportRequested, object: nil)
					}
					.keyboardShortcut("i", modifiers: [.command, .shift])

					Button(String(localized: "Export…")) {
						NotificationCenter.default.post(name: .hebeExportRequested, object: nil)
					}
					.keyboardShortcut("e", modifiers: [.command, .shift])
					.disabled(!menuState.canExport)
				}

				CommandMenu(String(localized: "Inventory")) {
					Button(InventorySection.furniture.title) {
						NotificationCenter.default.post(name: .hebeQuickAction, object: InventorySection.furniture)
					}
					.keyboardShortcut("1", modifiers: .command)

					Button(InventorySection.things.title) {
						NotificationCenter.default.post(name: .hebeQuickAction, object: InventorySection.things)
					}
					.keyboardShortcut("2", modifiers: .command)

					Divider()

					Button(String(localized: "Fill Random")) {
						NotificationCenter.default.post(name: .hebeFillRandomRequested, object: nil)
					}

					Button(String(localized: "Delete All"), role: .destructive) {
						NotificationCenter.default.post(name: .hebeDeleteAllRequested, object: nil)
					}
					.keyboardShortcut(.delete, modifiers: .command)
					.disabled(!menuState.canExport)
				}
			}
		#endif
		#if os(macOS)
			Settings {
				SettingsView()
			}
		#endif
	}

	#if os(macOS)
		private func updateStatusItemVisibility() {
			if settingsStore.showMenuBarStats {
				if statusItemController == nil {
					statusItemController = StatsStatusItemController()
				}
			} else if let statusItemController {
				statusItemController.remove()
				self.statusItemController = nil
			}
		}
	#endif

	@MainActor
	private func reloadContainerForUserChange() async {
		container = nil
		await beginBootstrapIfNeeded()
	}

	@MainActor
	private func beginBootstrapIfNeeded() async {
		NotificationBootstrap.shared.start()

		if container == nil && containerErrorMessage == nil {
			Task.detached {
				do {
					let iCloudAvailable = await CloudBootstrapService.shared.accountAvailable()
					let newContainer = try PersistenceController.makeBestAvailableContainer()
					await MainActor.run {
						container = newContainer
						shouldSeedData = true
						shouldCheckCloudAvailability = iCloudAvailable
					}
				} catch {
					await MainActor.run {
						containerErrorMessage = error.localizedDescription
					}
				}
			}
		}
	}
}

@MainActor
private final class NotificationBootstrap {
	static let shared = NotificationBootstrap()

	private var hasStarted = false

	func start() {
		guard hasStarted == false else { return }
		hasStarted = true

		Task {
			let center = UNUserNotificationCenter.current()

			do {
				_ = try await center.requestAuthorization(options: authorizationOptions)
			} catch {
				#if DEBUG
					print("Notification authorization request failed: \(error.localizedDescription)")
				#endif
			}

			registerForRemoteNotifications()
		}
	}

	private var authorizationOptions: UNAuthorizationOptions {
		#if os(tvOS) || os(watchOS)
			return [.alert, .sound]
		#else
			return [.alert, .sound, .badge]
		#endif
	}

	private func registerForRemoteNotifications() {
		PlatformApplication.platformShared.registerForRemoteNotifications()
	}
}

#if os(iOS) || os(visionOS)
	/// Background app-refresh: keeps the shared snapshot and widgets current
	/// (e.g. after CloudKit changes from another device) without launching.
	enum BackgroundRefresh {
		static let identifier = "com.lesvagabondages.hebe.refresh"

		/// Submits an app-refresh request. The handler is registered by the
		/// `.backgroundTask(.appRefresh:)` scene modifier.
		static func schedule() {
			let request = BGAppRefreshTaskRequest(identifier: identifier)
			request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
			try? BGTaskScheduler.shared.submit(request)
		}

		/// Recomputes the inventory snapshot from the store and reloads widgets.
		@MainActor
		static func perform() async {
			schedule()  // chain the next refresh first
			guard let container = try? PersistenceController.makeBestAvailableContainer() else { return }
			let context = ModelContext(container)
			guard let snapshot = try? InventoryRepository.snapshot(in: context) else { return }
			InventorySnapshotStore.save(snapshot)
			InventoryCountNotificationPublisher.evaluate(snapshot: snapshot)
			#if canImport(WidgetKit)
				WidgetCenter.shared.reloadAllTimelines()
			#endif
		}
	}
#endif
