import Foundation

struct TopShelfDiagnostics: Codable, Sendable {
	var lastProviderInitDate: Date?
	var providerInitCount: Int
	var lastProviderBundleIdentifier: String?
	var lastLoadDate: Date?
	var lastCompletionDate: Date?
	var loadCount: Int
	var lastAppPublishDate: Date?
	var appPublishCount: Int
	var lastTopShelfChangeRequestDate: Date?
	var topShelfChangeRequestCount: Int
	var lastPluginScanDate: Date?
	var embeddedTopShelfPluginFound: Bool?
	var embeddedPluginBundleIdentifiers: [String]
	var embeddedPluginFileNames: [String]
	var embeddedPluginExtensionPoints: [String]
	var embeddedPluginPrincipalClasses: [String]
	var embeddedTopShelfPluginMetadataValid: Bool?
	var lastFurnitureCount: Int
	var lastDistinctThingCount: Int
	var lastTotalThingCount: Int
	var lastImageURL: String?
	var usedFallbackImage: Bool
	var usedAppGroupContainer: Bool?
	var renderedOnMainThread: Bool?
	var lastActionURL: String?
	var lastError: String?
	var updatedAt: Date

	static let empty = TopShelfDiagnostics(
		lastProviderInitDate: nil,
		providerInitCount: 0,
		lastProviderBundleIdentifier: nil,
		lastLoadDate: nil,
		lastCompletionDate: nil,
		loadCount: 0,
		lastAppPublishDate: nil,
		appPublishCount: 0,
		lastTopShelfChangeRequestDate: nil,
		topShelfChangeRequestCount: 0,
		lastPluginScanDate: nil,
		embeddedTopShelfPluginFound: nil,
		embeddedPluginBundleIdentifiers: [],
		embeddedPluginFileNames: [],
		embeddedPluginExtensionPoints: [],
		embeddedPluginPrincipalClasses: [],
		embeddedTopShelfPluginMetadataValid: nil,
		lastFurnitureCount: 0,
		lastDistinctThingCount: 0,
		lastTotalThingCount: 0,
		lastImageURL: nil,
		usedFallbackImage: false,
		usedAppGroupContainer: nil,
		renderedOnMainThread: nil,
		lastActionURL: nil,
		lastError: nil,
		updatedAt: .now
	)
}

enum TopShelfDiagnosticsStore {
	private static var defaults: UserDefaults {
		UserDefaults(suiteName: SharedConstants.appGroupIdentifier) ?? .standard
	}

	private static let diagnosticsKey = "top_shelf_diagnostics_v1"

	static func load() -> TopShelfDiagnostics {
		guard let data = defaults.data(forKey: diagnosticsKey),
			let diagnostics = try? JSONDecoder().decode(TopShelfDiagnostics.self, from: data)
		else {
			return .empty
		}
		return diagnostics
	}

	static func save(_ diagnostics: TopShelfDiagnostics) {
		guard let data = try? JSONEncoder().encode(diagnostics) else { return }
		defaults.set(data, forKey: diagnosticsKey)
	}

	static func clear() {
		defaults.removeObject(forKey: diagnosticsKey)
	}

	static func recordLoadStart(snapshot: InventorySnapshot) {
		update { diagnostics in
			diagnostics.loadCount += 1
			diagnostics.lastLoadDate = .now
			diagnostics.lastFurnitureCount = snapshot.furnitureCount
			diagnostics.lastDistinctThingCount = snapshot.distinctThingCount
			diagnostics.lastTotalThingCount = snapshot.totalThingCount
			diagnostics.updatedAt = .now
		}
	}

	static func recordProviderInitialized(bundleIdentifier: String?) {
		update { diagnostics in
			diagnostics.providerInitCount += 1
			diagnostics.lastProviderInitDate = .now
			diagnostics.lastProviderBundleIdentifier = bundleIdentifier
			diagnostics.updatedAt = .now
		}
	}

	static func recordAppPublish(snapshot: InventorySnapshot) {
		update { diagnostics in
			diagnostics.appPublishCount += 1
			diagnostics.lastAppPublishDate = .now
			diagnostics.lastFurnitureCount = snapshot.furnitureCount
			diagnostics.lastDistinctThingCount = snapshot.distinctThingCount
			diagnostics.lastTotalThingCount = snapshot.totalThingCount
			diagnostics.updatedAt = .now
		}
	}

	static func recordTopShelfChangeRequested() {
		update { diagnostics in
			diagnostics.topShelfChangeRequestCount += 1
			diagnostics.lastTopShelfChangeRequestDate = .now
			diagnostics.updatedAt = .now
		}
	}

	static func recordEmbeddedPluginScan(
		bundleIdentifiers: [String],
		fileNames: [String],
		extensionPoints: [String],
		principalClasses: [String]
	) {
		let topShelfFound =
			bundleIdentifiers.contains(where: { $0.contains(".topshelf") })
			|| fileNames.contains(where: { $0.localizedCaseInsensitiveContains("topshelf") })
		let hasValidExtensionPoint =
			extensionPoints.contains("com.apple.tv-top-shelf")
			|| extensionPoints.contains("com.apple.tv-services")
		let hasValidPrincipalClass = principalClasses.contains(where: {
			$0 == "TopShelfProvider"
				|| $0 == "HebeTopShelf.TopShelfProvider"
				|| $0.hasSuffix(".TopShelfProvider")
		})
		let metadataValid = topShelfFound ? (hasValidExtensionPoint && hasValidPrincipalClass) : nil

		update { diagnostics in
			diagnostics.lastPluginScanDate = .now
			diagnostics.embeddedTopShelfPluginFound = topShelfFound
			diagnostics.embeddedPluginBundleIdentifiers = bundleIdentifiers.sorted()
			diagnostics.embeddedPluginFileNames = fileNames.sorted()
			diagnostics.embeddedPluginExtensionPoints = extensionPoints.sorted()
			diagnostics.embeddedPluginPrincipalClasses = principalClasses.sorted()
			diagnostics.embeddedTopShelfPluginMetadataValid = metadataValid
			diagnostics.updatedAt = .now
		}
	}

	static func recordImageResult(
		imageURL: URL?,
		usedFallbackImage: Bool,
		usedAppGroupContainer: Bool,
		renderedOnMainThread: Bool,
		error: String?
	) {
		update { diagnostics in
			diagnostics.lastImageURL = imageURL?.absoluteString
			diagnostics.usedFallbackImage = usedFallbackImage
			diagnostics.usedAppGroupContainer = usedAppGroupContainer
			diagnostics.renderedOnMainThread = renderedOnMainThread
			diagnostics.lastError = error
			diagnostics.updatedAt = .now
		}
	}

	static func recordCompletion(actionURL: URL?) {
		update { diagnostics in
			diagnostics.lastCompletionDate = .now
			diagnostics.lastActionURL = actionURL?.absoluteString
			diagnostics.updatedAt = .now
		}
	}

	private static func update(_ block: (inout TopShelfDiagnostics) -> Void) {
		var diagnostics = load()
		block(&diagnostics)
		save(diagnostics)
	}
}
