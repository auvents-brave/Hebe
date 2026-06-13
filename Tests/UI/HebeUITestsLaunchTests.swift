import XCTest

final class HebeUITestsLaunchTests: XCTestCase {
	func testLaunchPerformance() throws {
		measure(metrics: [XCTApplicationLaunchMetric()]) {
			let app = XCUIApplication()
			app.launchArguments += ["-skip-cloud-bootstrap"]
			app.launch()
		}
	}
}
