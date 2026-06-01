import SwiftUI
import WidgetKit

@main
struct HebeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HebeInventoryWidget()
        #if os(iOS) && !targetEnvironment(macCatalyst)
            HebeLiveBubbleLiveActivity()
        #endif
        #if os(iOS) || os(macOS)
        if #available(iOS 18, macOS 26, *) {
            HebeQuickActionControl()
        }
        #endif
    }
}
