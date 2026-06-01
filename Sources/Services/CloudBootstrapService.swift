import CloudKit
import Foundation

actor CloudBootstrapService {
    static let shared = CloudBootstrapService()

    /// Cached result — iCloud account status does not change during an app session.
    private var cachedAvailability: Bool?

    func initialize() async -> Bool {
        await accountAvailable()
    }

    func accountAvailable() async -> Bool {
        if let cached = cachedAvailability { return cached }

        if ProcessInfo.processInfo.arguments.contains("-skip-cloud-bootstrap") {
            cachedAvailability = true
            return true
        }

        let result = await checkAccountStatus()
        cachedAvailability = result
        return result
    }

    private func checkAccountStatus() async -> Bool {
        await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, _ in
                continuation.resume(returning: status == .available)
            }
        }
    }
}
