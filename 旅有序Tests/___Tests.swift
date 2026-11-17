import Testing
@testable import 旅有序

struct CalculationTests {
    @Test func documentedExamples() {
        let base = Plan.demo
        let c01 = Calculation.run(base)
        #expect(c01.physical == 915)
        #expect(c01.buffered == 935)
        #expect(c01.margin == 25)
        #expect(c01.latestStart == 785)
        let c02 = Calculation.run(base, start: 800)
        #expect(c02.buffered == 975)
        #expect(c02.margin == -15)
        var shortened = base
        shortened.activities[0].duration = 45
        let c04 = Calculation.run(shortened, start: 800)
        #expect(c04.buffered == 960)
        #expect(c04.margin == 0)
        shortened.activities[0].duration = 30
        let c03 = Calculation.run(shortened, start: 800)
        #expect(c03.buffered == 945)
        #expect(c03.margin == 15)
    }
    @Test func unknownLegHasNoFullResult() {
        var plan = Plan.demo
        plan.activities[1].incomingMinutes = nil
        let result = Calculation.run(plan)
        #expect(result.buffered == nil)
        #expect(result.margin == nil)
        #expect(result.latestStart == nil)
    }
    @Test func bookingConflictRemainsVisibleWithPositiveMargin() {
        var plan = Plan.demo
        plan.activities = [Activity(title: "预约", kind: .sightseeing, place: "示例地点", duration: 30, incomingMinutes: 0, samePlace: true, fixedStart: 780)]
        plan.plannedStart = 790
        plan.targetArrival = 900
        plan.finalTravel = 30
        plan.buffer = 10
        let result = Calculation.run(plan)
        #expect(result.margin == 40)
        #expect(result.issues.contains { $0.contains("预约") })
    }
}
