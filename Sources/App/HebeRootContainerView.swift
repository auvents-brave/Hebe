import SwiftData
import SwiftUI

struct HebeRootContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var bootstrapViewModel: BootstrapViewModel

    init(
        shouldSeedData: Bool = true,
        shouldCheckCloudAvailability: Bool = true,
        shouldWaitForRemoteData: Bool = true
    ) {
        _bootstrapViewModel = StateObject(wrappedValue: BootstrapViewModel(
            shouldSeedData: shouldSeedData,
            shouldCheckCloudAvailability: shouldCheckCloudAvailability,
            shouldWaitForRemoteData: shouldWaitForRemoteData
        ))
    }

    var body: some View {
        Group {
            if bootstrapViewModel.isReady {
                InventoryHomeView(iCloudAvailable: bootstrapViewModel.iCloudAvailable)
            } else {
                #if os(iOS)
                Color(.launchBackground).ignoresSafeArea()
                #else
                SplashScreenView()
                #endif
            }
        }
        .task {
            await bootstrapViewModel.start(context: modelContext)
        }
        .onAppear {
            #if !os(tvOS)
            _ = SettingsStore.shared
            #endif
        }
    }
}

#Preview("Root Container") { @MainActor in
    let schema = Schema([Furniture.self, Thing.self, FurnitureThing.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext
    try? InventoryRepository.fillRandomData(in: context)
    return HebeRootContainerView(
        shouldSeedData: false,
        shouldCheckCloudAvailability: false,
        shouldWaitForRemoteData: false
    )
    .modelContainer(container)
}
