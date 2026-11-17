import XCTest

final class PlanVisualUITests: XCTestCase {
    @MainActor
    func testCreatePlanIsAVisibleLargePrimaryAction() {
        let app = XCUIApplication(bundleIdentifier: "com.huankecontact.test")
        app.launchArguments.append("--ui-testing-no-animation")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()

        let create = app.buttons["新建返程计划"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(create.frame.height, 70)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "计划首页-大按钮与圆润字体"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        create.tap()
        XCTAssertTrue(app.staticTexts["填写返程信息"].waitForExistence(timeout: 10))
    }
}
