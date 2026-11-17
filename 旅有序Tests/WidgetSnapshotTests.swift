import XCTest
@testable import 旅有序

final class WidgetSnapshotTests: XCTestCase {
    func testUpcomingPlanUsesTrainTimeAndTarget() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "上海人民广场"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .ready
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        let snapshot = WidgetPlanSnapshot.preferred(from: [plan], now: now)
        XCTAssertEqual(snapshot?.departure, 17 * 60 + 30)
        XCTAssertEqual(snapshot?.targetArrival, 16 * 60 + 30)
        XCTAssertEqual(snapshot?.latestStart, 15 * 60 + 25)
        XCTAssertEqual(snapshot?.station, "上海虹桥站")
    }

    func testFinishedAndPastTrainDoNotAppear() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "上海人民广场"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .ready
        let later = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 18))!
        XCTAssertNil(WidgetPlanSnapshot.preferred(from: [plan], now: later))
        plan.status = .finished
        let earlier = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        XCTAssertNil(WidgetPlanSnapshot.preferred(from: [plan], now: earlier))
    }

    func testIncompleteOptionalStopStaysOffWidgetUntilTravelIsFilled() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .ready
        plan.activities = [Activity(title: "取行李", kind: .collectBag, place: "寄存处", duration: 15)]
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        XCTAssertNil(WidgetPlanSnapshot.preferred(from: [plan], now: now))
        plan.activities[0].incomingMinutes = 20
        plan.plannedStart = 14 * 60
        XCTAssertEqual(WidgetPlanSnapshot.preferred(from: [plan], now: now)?.latestStart, 14 * 60 + 50)
    }

    func testOptionalStopSnapshotKeepsChosenStartAndForwardArrival() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.activities = [Activity(title: "午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]
        plan.plannedStart = 14 * 60
        plan.status = .ready
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 19))!
        let snapshot = WidgetPlanSnapshot.preferred(from: [plan], now: now)
        XCTAssertEqual(snapshot?.plannedStart, 14 * 60)
        XCTAssertEqual(snapshot?.bufferedArrival, 15 * 60 + 55)
        XCTAssertEqual(snapshot?.latestStart, 14 * 60 + 35)
    }
}
