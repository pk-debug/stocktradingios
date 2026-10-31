import XCTest

final class stocktradingiosUITests: XCTestCase {
    @MainActor
    func testOfflineReviewAndConfirmOrder() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--reset-ui-data"]
        app.launch()
        app.buttons["enterOffline"].tap()
        XCTAssertTrue(app.navigationBars["Discover"].waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("RELIANCE\n")
        app.swipeUp()
        XCTAssertTrue(app.buttons["asset-RELIANCE"].waitForExistence(timeout: 10))
        app.buttons["asset-RELIANCE"].tap()
        app.buttons["reviewOrder"].tap()
        app.buttons["continueReview"].tap()
        XCTAssertTrue(app.buttons["confirmOrder"].exists)
        app.buttons["confirmOrder"].tap()
        XCTAssertTrue(app.navigationBars["RELIANCE"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Paper order completed. No real money moved."].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-ui-data" }
        app.launch()
        app.buttons["enterOffline"].tap()
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["BUY RELIANCE"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testWatchlistAndLargeTextNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-testing", "--reset-ui-data", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["enterOffline"].tap()
        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.staticTexts["Your watchlist is empty"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Account"].tap()
        XCTAssertTrue(app.navigationBars["Account & learning"].waitForExistence(timeout: 10))
    }
}
