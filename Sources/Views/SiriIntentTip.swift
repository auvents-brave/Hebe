import Euryale
import Foundation

// Siri tips target iOS / iPadOS / macOS (and Catalyst / visionOS). They are
// excluded on tvOS and watchOS, which have no usable Siri-shortcut surface
// (and the intents aren't built into the watchOS target anyway).
#if !os(tvOS) && !os(watchOS)

	// MARK: - SiriTipDisplayable conformances

	extension CountFurnitureIntent: SiriTipDisplayable {
		static let tipPhrase: LocalizedStringResource = "Count furniture in Hebe"
	}

	extension CountThingsIntent: SiriTipDisplayable {
		static let tipPhrase: LocalizedStringResource = "Count things in Hebe"
	}

	extension FurnitureContentsIntent: SiriTipDisplayable {
		static let tipPhrase: LocalizedStringResource = "Show furniture contents in Hebe"
	}

	extension FurnituresContainingThingIntent: SiriTipDisplayable {
		static let tipPhrase: LocalizedStringResource = "Find furniture by thing in Hebe"
	}

#endif
