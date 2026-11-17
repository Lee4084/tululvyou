import Foundation
import Testing
@testable import 旅有序

struct RemainingTimeTests {
    @Test func staleFinalLegKeepsItsPhaseAfterUpdating() {
        let now = Date()
        var execution = Execution(startedAt: now.addingTimeInterval(-3600))
        execution.phase = .finalTravel
        execution.expectedEnd = now.addingTimeInterval(-60)

        let updated = execution.updatingRemaining(30, now: now)
        #expect(updated?.phase == .finalTravel)
        #expect(updated?.remainingMinutes == 30)
        #expect(updated?.expectedEnd == now.addingTimeInterval(30 * 60))

        var plan = Plan()
        plan.targetArrival = 18 * 60
        plan.finalTravel = 45
        plan.buffer = 20
        let estimate = executionEstimate(plan, updated!, now: minuteOfDay(now)!)
        #expect(estimate.physical == minuteOfDay(updated!.expectedEnd))
        #expect(estimate.issues.isEmpty)
    }

    @Test func updatingTravelOrActivityDoesNotChangeTheCurrentStep() {
        let now = Date()
        for phase in [ExecutionPhase.travel, .activity] {
            var execution = Execution(startedAt: now)
            execution.phase = phase
            execution.expectedEnd = now.addingTimeInterval(-60)
            #expect(execution.updatingRemaining(15, now: now)?.phase == phase)
        }
    }

    @Test func suspendedPhaseIsRestoredAndInvalidMinutesAreRejected() {
        let now = Date()
        var execution = Execution(startedAt: now)
        execution.phase = .needsUpdate
        execution.suspendedPhase = .travel
        #expect(execution.updatingRemaining(20, now: now)?.phase == .travel)
        #expect(execution.updatingRemaining(0, now: now) == nil)
        #expect(execution.updatingRemaining(361, now: now) == nil)
    }
}
