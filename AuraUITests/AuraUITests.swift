import XCTest

@MainActor
final class AuraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsHomeDashboard() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["aura.home.title"].waitForExistence(timeout: 5))
    }
}
