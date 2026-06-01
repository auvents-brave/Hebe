import XCTest

final class HebeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainScreenShowsFurnitureTree() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-skip-cloud-bootstrap"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Hebe"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["furniture_tree_list"].waitForExistence(timeout: 10))
    }
}
