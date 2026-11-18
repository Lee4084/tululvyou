import XCTest

final class PlanCompletionJourneyTests: XCTestCase {
    @MainActor
    func testMissingDateOpensExistingPlanBasics() throws {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons["＋ 新建返程计划"].tap()
        XCTAssertTrue(app.staticTexts["填写返程信息"].exists)
        let formScreenshot = XCTAttachment(screenshot: app.screenshot())
        formScreenshot.name = "简化返程填写页"
        formScreenshot.lifetime = .keepAlways
        add(formScreenshot)
        app.buttons["保存并查看时间"].tap()
        XCTAssertTrue(app.staticTexts["返程时间"].exists)
        let detailScreenshot = XCTAttachment(screenshot: app.screenshot())
        detailScreenshot.name = "返程时间与缺项"
        detailScreenshot.lifetime = .keepAlways
        add(detailScreenshot)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "返程日期")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["填写返程信息"].exists)
    }
}
