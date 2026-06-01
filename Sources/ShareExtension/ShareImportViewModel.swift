import Foundation

@MainActor
final class ShareImportViewModel: ObservableObject {
    enum State {
        case loading
        case ready([FurnitureDigest])
        case empty
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isImporting = false

    private weak var extensionContext: NSExtensionContext?
    private var didStartLoading = false

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    func loadIfNeeded() {
        guard didStartLoading == false else { return }
        didStartLoading = true

        guard let extensionContext else {
            state = .failed(ShareImportError.missingContext.localizedDescription)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let digests = await SharedInventoryImportLoader.loadDigests(from: extensionContext.inputItems)
            state = digests.isEmpty ? .empty : .ready(digests)
        }
    }

    func importContent() {
        guard case .ready(let digests) = state, isImporting == false else { return }
        isImporting = true

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let imported = try await SharedInventoryStoreImporter.importDigests(digests)
                isImporting = false

                if imported {
                    extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                } else {
                    state = .empty
                }
            } catch {
                isImporting = false
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }
}
