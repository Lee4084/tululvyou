import XCTest

final class ReminderJourneyTests: XCTestCase {
    @MainActor
    func testReminderCanBeEnabledAndDisabledSeparately() throws {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments.append("--ui-testing-reminder")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons["未来"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "前往上海虹桥站")).firstMatch.tap()
        app.buttons["是否需要提醒"].tap()
        XCTAssertTrue(app.staticTexts["行程提醒"].waitForExistence(timeout: 10))
        let reminderSwitch = app.switches["是否需要提醒"]
        XCTAssertTrue(reminderSwitch.exists)
        reminderSwitch.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permissionAlert = springboard.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 5) {
            permissionAlert.buttons["允许"].tap()
        }
        XCTAssertTrue(app.staticTexts["已安排2条未来提醒"].waitForExistence(timeout: 20))
        let enabledScreenshot = XCTAttachment(screenshot: app.screenshot())
        enabledScreenshot.name = "独立提醒-已开启"
        enabledScreenshot.lifetime = .keepAlways
        add(enabledScreenshot)

        reminderSwitch.tap()
        XCTAssertTrue(app.staticTexts["提醒未开启，仍可使用全部规划功能。"].waitForExistence(timeout: 15))
        let disabledScreenshot = XCTAttachment(screenshot: app.screenshot())
        disabledScreenshot.name = "独立提醒-已关闭"
        disabledScreenshot.lifetime = .keepAlways
        add(disabledScreenshot)
    }
}
