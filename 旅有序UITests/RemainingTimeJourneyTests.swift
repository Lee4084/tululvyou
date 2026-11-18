import XCTest

final class RemainingTimeJourneyTests: XCTestCase {
    @MainActor
    func testOverdueStationLegCanUpdateRemainingTimeAndContinue() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments += ["--ui-testing-no-animation", "--ui-testing-stale-final"]
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.tabBars.buttons["进行中"].tap()

        XCTAssertTrue(app.buttons["更新剩余时间"].waitForExistence(timeout: 10))
        app.buttons["更新剩余时间"].tap()
        XCTAssertTrue(app.textFields["剩余分钟"].waitForExistence(timeout: 5))
        app.buttons["确认更新"].tap()
        XCTAssertTrue(app.staticTexts["请填写 1 到 360 分钟。"].exists)

        let field = app.textFields["剩余分钟"]
        field.tap()
        field.typeText("25")
        XCTAssertEqual(field.value as? String, "25")
        XCTAssertFalse(app.staticTexts["请填写 1 到 360 分钟。"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "进行中-更新剩余时间-可见输入"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["确认更新"].tap()
        XCTAssertTrue(app.buttons["已到车站"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["更新剩余时间"].exists)
        app.buttons["已到车站"].tap()
        app.alerts.buttons["确认"].tap()
        XCTAssertTrue(app.staticTexts["今天还没有进行中的行程"].waitForExistence(timeout: 10))
    }
}
