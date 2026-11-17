import Testing
import Foundation
@testable import 旅有序

struct PlanCompletionTests {
    @Test func blankPlanNamesTheFieldsToFill() {
        let items = PlanCompletion.missingItems(in: Plan())
        #expect(items.map(\.title) == ["返程日期", "从哪里出发", "乘车站", "列车发车时间", "去车站预计用时"])
    }

    @Test func demoPlanHasNoMissingFields() {
        #expect(PlanCompletion.missingItems(in: .demo).isEmpty)
    }

    @Test func missingLegLeadsToTheCorrectActivityEditor() {
        var plan = Plan.demo
        plan.activities[1].incomingMinutes = nil
        let items = PlanCompletion.missingItems(in: plan)
        #expect(items.count == 1)
        #expect(items[0].title == "去取行李的交通时间")
        #expect(items[0].destination == .activity(1))
        #expect(Calculation.run(plan).buffered == nil)
    }

    @Test func confirmedSamePlaceNeedsNoTravelTime() {
        var plan = Plan.demo
        plan.activities[0].incomingMinutes = nil
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
    }

    @Test func invalidArrivalOrderLinksToBasics() {
        var plan = Plan.demo
        plan.targetArrival = plan.plannedStart
        let items = PlanCompletion.missingItems(in: plan)
        #expect(items.map(\.title) == ["核对目标到站时间"])
        #expect(items[0].destination == .basics)
    }

    @Test func incompleteActivityNamesEachEditableField() {
        var plan = Plan.demo
        plan.activities[0].title = ""
        plan.activities[0].place = ""
        plan.activities[0].duration = nil
        plan.activities[0].samePlace = false
        plan.activities[0].incomingMinutes = nil
        let items = PlanCompletion.missingItems(in: plan)
        #expect(items.map(\.id) == ["activity-0-title", "activity-0-place", "activity-0-duration", "activity-0-leg"])
        #expect(items.allSatisfy { $0.destination == .activity(0) })
    }

    @Test func finalTravelCanBeConfirmedSamePlace() {
        var plan = Plan.demo
        plan.finalTravel = nil
        #expect(PlanCompletion.missingItems(in: plan).map(\.title) == ["去车站的交通时间"])
        plan.finalSamePlace = true
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
    }

    @Test func optionalTrainDepartureIsNotRequired() {
        var plan = Plan.demo
        plan.trainDeparture = nil
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
    }

    @Test func simpleJourneyUsesTrainDepartureToFindLeaveTime() {
        var plan = Plan()
        plan.day = Date()
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        let result = Calculation.run(plan)
        #expect(plan.effectiveTargetArrival == 16 * 60 + 30)
        #expect(result.latestStart == 15 * 60 + 25)
        #expect(result.complete)
        #expect(result.buffered == nil)
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
    }

    @Test func simpleJourneyDoesNotTreatMissingTravelAsZero() {
        var plan = Plan()
        plan.trainDeparture = 17 * 60 + 30
        #expect(Calculation.run(plan).latestStart == nil)
    }

    @Test func optionalStopChangesLatestDepartureOnlyWhenComplete() {
        var plan = Plan()
        plan.day = Date()
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        #expect(Calculation.run(plan).latestStart == 15 * 60 + 25)

        plan.activities = [Activity(title: "吃午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]
        plan.plannedStart = 14 * 60 + 35
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
        #expect(Calculation.run(plan).latestStart == 14 * 60 + 35)
        let atLatestStart = Calculation.run(plan, start: 14 * 60 + 35)
        #expect(atLatestStart.stops.first?.start == 14 * 60 + 55)
        #expect(atLatestStart.physical == 16 * 60 + 10)
        #expect(atLatestStart.buffered == 16 * 60 + 30)
        plan.activities[0].incomingMinutes = nil
        #expect(PlanCompletion.missingItems(in: plan).map(\.id) == ["activity-0-leg"])
        #expect(Calculation.run(plan).latestStart == nil)
    }

    @Test func optionalStopUsesChosenDepartureForForwardSchedule() {
        var plan = Plan()
        plan.day = Date()
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.activities = [Activity(title: "午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]
        plan.plannedStart = 14 * 60

        let result = Calculation.run(plan)
        #expect(PlanCompletion.missingItems(in: plan).isEmpty)
        #expect(result.stops.first?.start == 14 * 60 + 20)
        #expect(result.stops.first?.end == 14 * 60 + 50)
        #expect(result.physical == 15 * 60 + 35)
        #expect(result.buffered == 15 * 60 + 55)
        #expect(result.margin == 35)
        #expect(result.latestStart == 14 * 60 + 35)
    }

    @Test func optionalStopNeedsDepartureTimeInsteadOfGuessingLatestStart() {
        var plan = Plan()
        plan.day = Date()
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.activities = [Activity(title: "午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]

        #expect(PlanCompletion.missingItems(in: plan).map(\.id) == ["plannedStart"])
        #expect(Calculation.run(plan).stops.isEmpty)
        #expect(Calculation.run(plan).physical == nil)
    }

    @Test func lateChosenStartStillComputesForwardArrivalAndWarnsAboutTrain() {
        var plan = Plan()
        plan.day = Date()
        plan.startPlace = "酒店"
        plan.stationPlace = "上海虹桥站"
        plan.trainDeparture = 17 * 60 + 30
        plan.finalTravel = 45
        plan.activities = [Activity(title: "午饭", kind: .meal, place: "餐厅", duration: 30, incomingMinutes: 20)]
        plan.plannedStart = 16 * 60

        let result = Calculation.run(plan)
        #expect(result.latestStart == 14 * 60 + 35)
        #expect(result.stops.first?.start == 16 * 60 + 20)
        #expect(result.physical == 17 * 60 + 35)
        #expect(result.margin == -85)
        #expect(result.issues.contains { $0.contains("列车发车") })
    }
}
