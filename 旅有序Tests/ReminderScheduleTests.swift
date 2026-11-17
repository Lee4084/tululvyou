import XCTest
@testable import 旅有序

final class ReminderScheduleTests: XCTestCase {
    func testSimplePlanSchedulesLatestDepartureAndArrivalOnly() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "上海人民广场"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .ready
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!

        let candidates = ReminderSchedule.candidates(for: plan, now: now)
        XCTAssertEqual(candidates.map(\.kind), [.latestStart, .targetArrival])
        XCTAssertEqual(candidates.map { minuteOfDay($0.date) }, [15 * 60 + 25, 16 * 60 + 30])
    }

    func testPastMomentsAreNotScheduledAndDemoIsExcluded() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "上海人民广场"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .ready
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 16))!
        XCTAssertEqual(ReminderSchedule.candidates(for: plan, now: now).map(\.kind), [.targetArrival])
        plan.isDemo = true
        XCTAssertTrue(ReminderSchedule.candidates(for: plan, now: now).isEmpty)
    }

    func testOptionalStopIncludesChosenStartReminder() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.activities = [Activity(title: "午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]
        plan.plannedStart = 14 * 60
        plan.status = .ready
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        let candidates = ReminderSchedule.candidates(for: plan, now: now)
        XCTAssertEqual(candidates.map(\.kind), [.plannedStart, .latestStart, .targetArrival])
        XCTAssertEqual(candidates.map { minuteOfDay($0.date) }, [14 * 60, 14 * 60 + 35, 16 * 60 + 30])
    }

    func testActivePlanOnlyKeepsTargetArrivalAndDuplicateMomentsMerge() {
        var plan = Plan()
        plan.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20))
        plan.startPlace = "上海人民广场"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.status = .active
        let now = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 12))!
        XCTAssertEqual(ReminderSchedule.candidates(for: plan, now: now).map(\.kind), [.targetArrival])

        plan.status = .ready
        plan.simpleJourney = false
        plan.city = "上海"
        plan.plannedStart = 15 * 60
        plan.targetArrival = 16 * 60 + 15
        plan.finalTravel = 40
        plan.buffer = 20
        plan.activities = [Activity(title: "取行李", place: "上海人民广场", duration: 15, samePlace: true)]
        XCTAssertEqual(ReminderSchedule.candidates(for: plan, now: now).map(\.kind), [.plannedStart, .targetArrival])
    }
}
