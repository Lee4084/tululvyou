import XCTest

final class KeyboardDismissalUITests: XCTestCase {
    @MainActor
    func testTappingBlankAreaDismissesKeyboardWithoutLosingInput() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments.append("--ui-testing-no-animation")
        app.launch()
        app.buttons["新建返程计划"].tap()

        let firstField = app.textFields["请填写"].firstMatch
        XCTAssertTrue(firstField.waitForExistence(timeout: 10))
        firstField.tap()
        firstField.typeText("酒店大堂")
        XCTAssertTrue(app.keyboards.firstMatch.exists)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.42)).tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertEqual(firstField.value as? String, "酒店大堂")
    }
}
