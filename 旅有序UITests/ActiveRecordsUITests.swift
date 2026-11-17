import XCTest

final class ActiveRecordsUITests: XCTestCase {
    @MainActor
    func testActiveTabIncludesHistoryAndDemo() {
        let app = XCUIApplication(bundleIdentifier: "com.huankecontact.test")
        app.launchArguments.append("--ui-testing-no-animation")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.tabBars.buttons["进行中"].tap()

        XCTAssertTrue(app.staticTexts["行程记录"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["还没有行程记录"].exists)
        XCTAssertTrue(app.buttons["查看演示计划"].exists)
    }
}
