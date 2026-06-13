import SwiftUI

#if os(macOS)
	import AppKit
	typealias PlatformViewController = NSViewController
#else
	import UIKit
	typealias PlatformViewController = UIViewController
#endif

@objc(ShareViewController)
final class ShareViewController: PlatformViewController {
	#if os(iOS) || os(visionOS)
		private var hostingController: UIHostingController<ShareImportPreviewView>?
	#endif

	private var viewModel: ShareImportViewModel?
	private var didTriggerImport = false

	#if os(macOS)
		override func loadView() {
			view = NSView()
		}
	#endif

	override func viewDidLoad() {
		super.viewDidLoad()

		#if os(iOS) || os(visionOS)
			setupIOSPreviewUI()
		#else
			setupMacOSMinimalUI()
		#endif
	}

	#if os(iOS) || os(visionOS)
		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			viewModel?.loadIfNeeded()
		}
	#else
		override func viewDidAppear() {
			super.viewDidAppear()
			importIfNeeded()
		}
	#endif

	// MARK: - iOS Preview UI Setup

	#if os(iOS) || os(visionOS)
		private func setupIOSPreviewUI() {
			view.backgroundColor = .systemBackground

			let viewModel = ShareImportViewModel(extensionContext: extensionContext)
			let rootView = ShareImportPreviewView(viewModel: viewModel)
			let hostingController = UIHostingController(rootView: rootView)

			addChild(hostingController)
			hostingController.view.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(hostingController.view)

			NSLayoutConstraint.activate([
				hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
				hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
				hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			])

			hostingController.didMove(toParent: self)
			self.hostingController = hostingController
			self.viewModel = viewModel

			preferredContentSize = CGSize(width: 700, height: 640)
		}
	#endif

	// MARK: - macOS Direct Import

	#if os(macOS)
		private func setupMacOSMinimalUI() {
			preferredContentSize = NSSize(width: 320, height: 120)
		}

		private func importIfNeeded() {
			guard didTriggerImport == false else { return }
			didTriggerImport = true

			Task { @MainActor [weak self] in
				guard let self else { return }

				guard let extensionContext = self.extensionContext else {
					self.extensionContext?.cancelRequest(withError: ShareImportError.missingContext)
					return
				}

				let digests = await SharedInventoryImportLoader.loadDigests(from: extensionContext.inputItems)
				guard digests.isEmpty == false else {
					presentNothingToImportAlert()
					extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
					return
				}

				do {
					_ = try await SharedInventoryStoreImporter.importDigests(digests)
					extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
				} catch {
					extensionContext.cancelRequest(withError: error)
				}
			}
		}

		private func presentNothingToImportAlert() {
			let alert = NSAlert()
			alert.messageText = String(localized: "Nothing to import")
			alert.informativeText = "\(String(localized: "Expected XML"))\n\n\(ShareImportSchema.exampleXML)"
			alert.alertStyle = .informational
			alert.addButton(withTitle: String(localized: "OK"))
			alert.runModal()
		}
	#endif
}
