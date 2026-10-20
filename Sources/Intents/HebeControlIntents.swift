import AppIntents

enum HebeOpenTarget: String, AppEnum {
	case home

	static let typeDisplayRepresentation = TypeDisplayRepresentation("Hebe Destination")
	static let caseDisplayRepresentations: [HebeOpenTarget: DisplayRepresentation] = [
		.home: DisplayRepresentation("Home")
	]
}

struct OpenHebeIntent: OpenIntent {
	static let title: LocalizedStringResource = "Open Hebe"

	@Parameter(title: "Target")
	var target: HebeOpenTarget

	init() {
		self.target = .home
	}

	init(target: HebeOpenTarget) {
		self.target = target
	}

	func perform() async throws -> some IntentResult {
		.result()
	}
}
