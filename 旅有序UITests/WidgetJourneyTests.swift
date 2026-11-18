import XCTest

final class WidgetJourneyTests: XCTestCase {
    @MainActor
    func testWidgetGalleryIsAvailableFromHomeScreen() throws {
        let app = XCUIApplication(bundleIdentifier: "com.lvyouxucn.app")
        app.launchArguments.append("--ui-testing-reminder")
        app.launch()
        app.buttons["进入途鹿旅游"].tap()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.waitForExistence(timeout: 10))
        let home = XCTAttachment(screenshot: springboard.screenshot())
        home.name = "主屏幕-添加小组件前"
        home.lifetime = .keepAlways
        add(home)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)).press(forDuration: 1.5)
        let edit = XCTAttachment(screenshot: springboard.screenshot())
        edit.name = "主屏幕-编辑模式"
        edit.lifetime = .keepAlways
        add(edit)
        springboard.buttons["编辑"].tap()
        let menu = XCTAttachment(screenshot: springboard.screenshot())
        menu.name = "主屏幕-编辑菜单"
        menu.lifetime = .keepAlways
        add(menu)
        springboard.buttons["添加小组件"].tap()
        let gallery = XCTAttachment(screenshot: springboard.screenshot())
        gallery.name = "系统小组件列表"
        gallery.lifetime = .keepAlways
        add(gallery)
        let search = springboard.searchFields["搜索小组件"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("途鹿旅游")
        sleep(3)
        let result = XCTAttachment(screenshot: springboard.screenshot())
        result.name = "系统小组件-途鹿旅游搜索"
        result.lifetime = .keepAlways
        add(result)
        XCTAssertTrue(springboard.cells["途鹿旅游"].waitForExistence(timeout: 10))
        springboard.cells["途鹿旅游"].tap()
        sleep(3)
        let preview = XCTAttachment(screenshot: springboard.screenshot())
        preview.name = "途鹿旅游小组件预览"
        preview.lifetime = .keepAlways
        add(preview)
    }
}
