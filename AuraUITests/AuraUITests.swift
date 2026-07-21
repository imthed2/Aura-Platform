import XCTest

@MainActor
final class AuraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsHomeDashboard() {
        let app = XCUIApplication()
        app.launch()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()
        XCTAssertTrue(app.staticTexts["aura.home.title"].waitForExistence(timeout: 5))
    }
}
