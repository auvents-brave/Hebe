import Foundation
import OSLog
import TVServices
import UIKit

@objc(TopShelfProvider)
final class TopShelfProvider: TVTopShelfContentProvider {
	private let logger = Logger(subsystem: "com.lesvagabondages.hebe.topshelf", category: "TopShelf")

	override init() {
		super.init()
		TopShelfDiagnosticsStore.recordProviderInitialized(bundleIdentifier: Bundle.main.bundleIdentifier)
		logger.info(
			"Top Shelf provider initialized. bundleID=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)")
	}

	override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
		let snapshot = InventorySnapshotStore.load()
		TopShelfDiagnosticsStore.recordLoadStart(snapshot: snapshot)

		logger.info(
			"Loading Top Shelf. furniture=\(snapshot.furnitureCount, privacy: .public) types=\(snapshot.distinctThingCount, privacy: .public) total=\(snapshot.totalThingCount, privacy: .public)"
		)

		let item = TVTopShelfItem(identifier: Self.itemIdentifier(for: snapshot))
		item.title = L10n.TopShelf.title
		item.expirationDate = Date().addingTimeInterval(300)

		if let imageURL = topShelfImageURL(for: snapshot) {
			logger.info("Top Shelf image URL: \(imageURL.absoluteString, privacy: .public)")
			item.setImageURL(imageURL, for: .screenScale1x)
			item.setImageURL(imageURL, for: .screenScale2x)
		} else {
			logger.error("Top Shelf image URL generation failed.")
		}

		let actionURL = URL(string: "hebe://furniture")
		if let url = actionURL {
			item.displayAction = TVTopShelfAction(url: url)
			logger.info("Top Shelf action URL: \(url.absoluteString, privacy: .public)")
		}

		let content = TVTopShelfInsetContent(items: [item])
		TopShelfDiagnosticsStore.recordCompletion(actionURL: actionURL)
		completionHandler(content)
	}

	private func topShelfImageURL(for snapshot: InventorySnapshot) -> URL? {
		let topShelfDirectory = topShelfDirectoryURL()
		let renderedOnMainThread = Thread.isMainThread
		let renderResult: RenderResult

		if renderedOnMainThread {
			renderResult = Self.renderTopShelfImage(for: snapshot, topShelfDirectory: topShelfDirectory.url)
		} else {
			renderResult = DispatchQueue.main.sync {
				Self.renderTopShelfImage(for: snapshot, topShelfDirectory: topShelfDirectory.url)
			}
		}

		if let error = renderResult.error {
			logger.error("Top Shelf render error: \(error, privacy: .public)")
		}

		TopShelfDiagnosticsStore.recordImageResult(
			imageURL: renderResult.imageURL,
			usedFallbackImage: renderResult.usedFallbackImage,
			usedAppGroupContainer: topShelfDirectory.usingAppGroup,
			renderedOnMainThread: renderedOnMainThread,
			error: renderResult.error
		)

		return renderResult.imageURL
	}

	private static func renderTopShelfImage(for snapshot: InventorySnapshot, topShelfDirectory: URL) -> RenderResult {
		try? FileManager.default.createDirectory(at: topShelfDirectory, withIntermediateDirectories: true)

		let imageURL = topShelfDirectory.appendingPathComponent(imageFileName(for: snapshot))
		cleanupOldImages(in: topShelfDirectory, keeping: imageURL)
		let size = TVTopShelfInsetContent.imageSize
		let renderer = UIGraphicsImageRenderer(size: size)

		let image = renderer.image { context in
			UIColor(red: 0.08, green: 0.16, blue: 0.3, alpha: 1.0).setFill()
			context.fill(CGRect(origin: .zero, size: size))

			let title = L10n.TopShelf.title
			let counts = L10n.TopShelf.counts(
				furniture: snapshot.furnitureCount,
				types: snapshot.distinctThingCount,
				total: snapshot.totalThingCount
			)

			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 80, weight: .bold),
				.foregroundColor: UIColor.white,
			]
			let countsAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 44, weight: .semibold),
				.foregroundColor: UIColor(white: 0.95, alpha: 1.0),
			]

			let titleSize = (title as NSString).size(withAttributes: titleAttributes)
			let countsSize = (counts as NSString).size(withAttributes: countsAttributes)

			let titleOrigin = CGPoint(x: 120, y: (size.height - titleSize.height - countsSize.height - 24) / 2)
			let countsOrigin = CGPoint(x: 120, y: titleOrigin.y + titleSize.height + 24)

			(title as NSString).draw(at: titleOrigin, withAttributes: titleAttributes)
			(counts as NSString).draw(at: countsOrigin, withAttributes: countsAttributes)
		}

		guard let data = image.pngData() else {
			let fallbackURL = Bundle.main.url(forResource: "shelf", withExtension: "png")
			return RenderResult(
				imageURL: fallbackURL,
				usedFallbackImage: fallbackURL != nil,
				error: "pngData returned nil"
			)
		}

		do {
			try data.write(to: imageURL, options: [.atomic])
			return RenderResult(imageURL: imageURL, usedFallbackImage: false, error: nil)
		} catch {
			let fallbackURL = Bundle.main.url(forResource: "shelf", withExtension: "png")
			return RenderResult(
				imageURL: fallbackURL,
				usedFallbackImage: fallbackURL != nil,
				error: "Unable to write rendered image: \(error.localizedDescription)"
			)
		}
	}

	private func topShelfDirectoryURL() -> (url: URL, usingAppGroup: Bool) {
		if let containerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
		) {
			logger.info("Using App Group directory for Top Shelf image.")
			return (
				containerURL.appendingPathComponent("TopShelf", isDirectory: true),
				true
			)
		}

		logger.warning("Falling back to temporary directory for Top Shelf image.")
		return (
			FileManager.default.temporaryDirectory.appendingPathComponent("TopShelf", isDirectory: true),
			false
		)
	}

	private static func itemIdentifier(for snapshot: InventorySnapshot) -> String {
		let timestamp = Int(snapshot.generatedAt.timeIntervalSince1970 * 1000)
		return
			"inventory.summary.\(snapshot.furnitureCount).\(snapshot.distinctThingCount).\(snapshot.totalThingCount).\(timestamp)"
	}

	private static func imageFileName(for snapshot: InventorySnapshot) -> String {
		let timestamp = Int(snapshot.generatedAt.timeIntervalSince1970 * 1000)
		return
			"top_shelf_\(snapshot.furnitureCount)_\(snapshot.distinctThingCount)_\(snapshot.totalThingCount)_\(timestamp).png"
	}

	private static func cleanupOldImages(in directory: URL, keeping imageURL: URL) {
		guard
			let contents = try? FileManager.default.contentsOfDirectory(
				at: directory,
				includingPropertiesForKeys: nil
			)
		else {
			return
		}

		for url in contents where url.pathExtension.lowercased() == "png" && url != imageURL {
			try? FileManager.default.removeItem(at: url)
		}
	}

	private struct RenderResult {
		let imageURL: URL?
		let usedFallbackImage: Bool
		let error: String?
	}
}
