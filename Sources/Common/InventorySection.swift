import Foundation

/// The two top-level inventory sections — furniture and the things they hold.
///
/// A lightweight, Foundation-only value shared between the app and its
/// extensions (widget, share, watch); carries its display title and SF Symbol.
enum InventorySection: String, CaseIterable, Identifiable {
	case furniture
	case things

	var id: String { rawValue }

	var title: String {
		switch self {
		case .furniture:
			return String(localized: "Furniture")
		case .things:
			return String(localized: "Things")
		}
	}

	/// SF Symbol representing the section — single source of truth for the icon.
	var systemImage: String {
		switch self {
		case .furniture:
			return "cabinet.fill"
		case .things:
			return "shippingbox.fill"
		}
	}
}
