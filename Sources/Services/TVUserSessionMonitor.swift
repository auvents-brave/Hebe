import Foundation
import UIKit

@MainActor
final class TVUserSessionMonitor: ObservableObject {
	private var tokens: [NSObjectProtocol] = []

	func start() {
		guard tokens.isEmpty else { return }

		let center = NotificationCenter.default
		let notifyChange: @Sendable (Notification) -> Void = { _ in
			Task { @MainActor in
				NotificationCenter.default.post(name: .hebeTVUserDidChange, object: nil)
			}
		}

		tokens.append(
			center.addObserver(
				forName: Notification.Name("TVUserManagerCurrentUserIdentifierDidChange"),
				object: nil,
				queue: .main,
				using: notifyChange
			)
		)
	}

	deinit {
		MainActor.assumeIsolated {
			for token in tokens {
				NotificationCenter.default.removeObserver(token)
			}
		}
	}
}
