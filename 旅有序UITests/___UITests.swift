import XCTest
final class LvYouXuUITests: XCTestCase {
    func testBrandNameAcrossWelcomeHomeAndAbout() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments.append("--ui-testing-no-animation")
        app.launch()
        XCTAssertTrue(app.staticTexts["途鹿旅游"].waitForExistence(timeout: 10))
        app.buttons["进入途鹿旅游"].tap()
        XCTAssertTrue(app.staticTexts["途鹿旅游"].waitForExistence(timeout: 10))
        app.tabBars.buttons["我的"].tap()
        app.buttons["帮助与关于"].tap()
        XCTAssertTrue(app.staticTexts["关于途鹿旅游"].waitForExistence(timeout: 10))
    }

    func testLaunchShowsThreeTabs() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launch()
        XCTAssertTrue(app.staticTexts["时间提醒"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["路线查看"].exists)
        app.buttons["进入途鹿旅游"].tap()
        XCTAssertTrue(app.tabBars.buttons["计划"].exists)
        XCTAssertTrue(app.tabBars.buttons["进行中"].exists)
        XCTAssertTrue(app.tabBars.buttons["我的"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "黑灰主题-计划首页"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.tabBars.buttons["我的"].tap()
        app.buttons["设置与数据"].tap()
        XCTAssertTrue(app.staticTexts["外观 · 黑灰色调"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["计划"].exists)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "黑灰主题-设置页"
        settings.lifetime = .keepAlways
        add(settings)
    }

    func testWelcomeCreatesPlan() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launch()
        app.buttons["新建返程计划"].tap()
        XCTAssertTrue(app.staticTexts["填写返程信息"].waitForExistence(timeout: 10))
    }
}
