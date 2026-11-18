import XCTest

final class RouteMapJourneyTests: XCTestCase {
    @MainActor
    func testTripWithoutStopsKeepsOriginalMapFlow() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments += ["--ui-testing-no-animation", "--ui-testing-route"]
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "前往上海虹桥站")).firstMatch.tap()
        app.buttons["查看真实路线图"].tap()

        XCTAssertTrue(app.buttons["在高德查看公共交通路线"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["地图站点顺序"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "中途地点")).firstMatch.exists)
    }

    @MainActor
    func testSavedStopAppearsAsOrderedMapPoint() {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments += ["--ui-testing-no-animation", "--ui-testing-route-stops"]
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "前往上海虹桥站")).firstMatch.tap()
        app.buttons["查看真实路线图"].tap()

        let marked = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已在地图标记1个中途地点")).firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["地图站点顺序"].exists)
        XCTAssertTrue(app.staticTexts["上海人民广场 → 上海博物馆 → 上海虹桥站"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "真实路线图-中途地点与连线"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSavedTripOpensRealRouteMap() throws {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments.append("--ui-testing-route")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "前往上海虹桥站")).firstMatch.tap()
        app.buttons["查看真实路线图"].tap()
        XCTAssertTrue(app.staticTexts["真实路线图"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["在高德查看公共交通路线"].waitForExistence(timeout: 30))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "真实路线图-公共交通入口"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["打车／驾车"].tap()
        XCTAssertTrue(app.buttons["在高德查看打车／驾车路线"].waitForExistence(timeout: 30))
        let drivingScreenshot = XCTAttachment(screenshot: app.screenshot())
        drivingScreenshot.name = "真实路线图-驾车路线"
        drivingScreenshot.lifetime = .keepAlways
        add(drivingScreenshot)
        app.buttons["公共交通"].tap()
        app.buttons["在高德查看公共交通路线"].tap()
        let locationAlert = app.alerts.firstMatch
        if locationAlert.waitForExistence(timeout: 15) {
            locationAlert.buttons["不允许"].tap()
        }
        sleep(10)
        let transitScreenshot = XCTAttachment(screenshot: app.screenshot())
        transitScreenshot.name = "高德公共交通页面"
        transitScreenshot.lifetime = .keepAlways
        add(transitScreenshot)
    }
}
