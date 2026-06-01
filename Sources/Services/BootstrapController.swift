import Foundation
import SwiftData

@MainActor
final class BootstrapViewModel: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var iCloudAvailable = false

    private var hasStarted = false
    private let minimumSplashDuration: TimeInterval = 0.0
    private let shouldSeedData: Bool
    private let shouldCheckCloudAvailability: Bool
    private let shouldWaitForRemoteData: Bool
    private let remoteDataWaitTimeout: TimeInterval = 4.0

    init(shouldSeedData: Bool, shouldCheckCloudAvailability: Bool, shouldWaitForRemoteData: Bool) {
        self.shouldSeedData = shouldSeedData
        self.shouldCheckCloudAvailability = shouldCheckCloudAvailability
        self.shouldWaitForRemoteData = shouldWaitForRemoteData
    }

    func start(context: ModelContext) async {
        guard !hasStarted else { return }
        hasStarted = true
        let startTime = Date()

        if shouldCheckCloudAvailability {
            iCloudAvailable = await CloudBootstrapService.shared.initialize()
        } else {
            iCloudAvailable = false
        }
        if shouldSeedData {
            try? await InventoryRepository.ensureSeedData(in: context, iCloudAvailable: iCloudAvailable)
        }
        if shouldWaitForRemoteData {
            await waitForRemoteDataIfNeeded(context: context)
        }
        InventorySnapshotPublisher.publish(context: context)

        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minimumSplashDuration {
            let remaining = minimumSplashDuration - elapsed
            let nanoseconds = UInt64(remaining * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }

        isReady = true
    }

    private func waitForRemoteDataIfNeeded(context: ModelContext) async {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < remoteDataWaitTimeout {
            if (try? InventoryRepository.hasFurniture(in: context)) == true {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
