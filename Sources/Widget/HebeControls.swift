import AppIntents
import SwiftUI
import WidgetKit

#if os(iOS) || os(macOS)
	@available(iOS 18.0, macOS 26.0, *)
	struct HebeQuickActionControl: ControlWidget {
		static let kind = "com.lesvagabondages.hebe.control.open"

		var body: some ControlWidgetConfiguration {
			StaticControlConfiguration(kind: Self.kind) {
				ControlWidgetButton(action: OpenHebeIntent(target: .home)) {
					Label("Open Hebe", systemImage: "shippingbox")
				}
			}
			.displayName("Hebe")
			.description("Open Hebe")
		}
	}
#endif
