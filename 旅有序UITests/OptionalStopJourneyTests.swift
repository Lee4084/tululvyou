import XCTest

final class OptionalStopJourneyTests: XCTestCase {
    @MainActor
    func testStopFieldsAppearOnlyAfterAddingAndCanBeRemoved() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons["新建返程计划"].tap()

        XCTAssertTrue(app.buttons["添加中途行程"].exists)
        XCTAssertFalse(app.textFields["第1站做什么"].exists)
        app.buttons["添加中途行程"].tap()
        let departureTime = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "计划出发时间"))
            .firstMatch
        XCTAssertTrue(departureTime.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "当前计划出发：")).firstMatch.exists)
        XCTAssertTrue(app.textFields["第1站做什么"].exists)
        XCTAssertTrue(app.textFields["第1站地点"].exists)
        XCTAssertTrue(app.buttons["移除第1站"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "新建返程计划-可选中途行程"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["移除第1站"].tap()
        XCTAssertFalse(app.textFields["第1站做什么"].exists)
    }
}
