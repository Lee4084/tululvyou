import XCTest

final class PersonalCenterUITests: XCTestCase {
    @MainActor
    func testWishesUnfinishedTripSettingsAndLegalPages() {
        let app = XCUIApplication(bundleIdentifier: "com.huankecontact.test")
        app.launchArguments += ["--ui-testing-no-animation", "--ui-testing-personal"]
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.tabBars.buttons["我的"].tap()

        XCTAssertTrue(app.staticTexts["个人中心"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["未完成的旅程"].exists)
        XCTAssertTrue(app.staticTexts["提前结束的返程"].exists)

        let wish = app.textFields["写下一个想去的地方或心愿"]
        wish.tap()
        wish.typeText("去海边看日落")
        app.buttons["加入心愿墙"].tap()
        XCTAssertTrue(app.staticTexts["去海边看日落"].exists)

        app.buttons["隐私政策"].tap()
        XCTAssertTrue(app.staticTexts["lvyouxu@gmail.com"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["查看在线版本"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "草案")).firstMatch.exists)
        let privacyScreenshot = XCTAttachment(screenshot: app.screenshot())
        privacyScreenshot.name = "正式隐私政策"
        privacyScreenshot.lifetime = .keepAlways
        add(privacyScreenshot)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["App 使用协议"].tap()
        XCTAssertTrue(app.staticTexts["lvyouxu@gmail.com"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["查看在线版本"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "草案")).firstMatch.exists)
        let agreementScreenshot = XCTAttachment(screenshot: app.screenshot())
        agreementScreenshot.name = "正式App使用协议"
        agreementScreenshot.lifetime = .keepAlways
        add(agreementScreenshot)
    }
}
