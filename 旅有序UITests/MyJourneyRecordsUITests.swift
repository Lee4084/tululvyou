import XCTest

final class MyJourneyRecordsUITests: XCTestCase {
    @MainActor
    func testRecordsCanBeViewedAndDeletedAfterConfirmation() {
        let app = XCUIApplication(bundleIdentifier: "com.huankecontact.test")
        app.launchArguments += ["--ui-testing-no-animation", "--ui-testing-journeys"]
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.tabBars.buttons["我的"].tap()

        app.buttons["我的旅程记录"].tap()
        XCTAssertTrue(app.staticTexts["当前旅程"].exists)
        XCTAssertTrue(app.staticTexts["待出发的返程"].exists)
        XCTAssertTrue(app.staticTexts["已完成的返程"].exists)
        XCTAssertTrue(app.staticTexts["提前结束的返程"].exists)
        XCTAssertFalse(app.buttons["删除旅程：当前旅程"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "我的旅程记录-管理列表"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["查看旅程：已完成的返程"].tap()
        XCTAssertTrue(app.staticTexts["记录详情"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        let delete = app.buttons["删除旅程：提前结束的返程"]
        delete.tap()
        XCTAssertTrue(app.alerts.staticTexts["删除此计划及关联记录？此操作不可撤销。"].exists)
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["提前结束的返程"].exists)

        delete.tap()
        app.alerts.buttons["删除旅程"].tap()
        XCTAssertFalse(app.staticTexts["提前结束的返程"].exists)
        XCTAssertTrue(app.staticTexts["已完成的返程"].exists)
    }
}
