import Foundation
import WidgetKit

struct WidgetPlanSnapshot: Codable, Equatable {
    var planID: UUID
    var day: Date
    var station: String
    var departure: Int
    var targetArrival: Int
    var latestStart: Int?
    var plannedStart: Int?
    var bufferedArrival: Int?

    static func preferred(from plans: [Plan], now: Date = Date()) -> WidgetPlanSnapshot? {
        let today = chinaCalendar.startOfDay(for: now)
        let eligible = plans.compactMap { plan -> (Plan, Date)? in
            guard [.ready, .active].contains(plan.status), !plan.isDemo,
                  PlanCompletion.missingItems(in: plan).isEmpty,
                  (plan.status == .active || Calculation.run(plan).issues.isEmpty),
                  let day = plan.day,
                  let departure = plan.trainDeparture,
                  let trainDate = minutesDate(day, departure), trainDate > now,
                  chinaCalendar.startOfDay(for: day) >= today else { return nil }
            return (plan, trainDate)
        }
        guard let selected = eligible.sorted(by: {
            if $0.0.status == .active && $1.0.status != .active { return true }
            if $1.0.status == .active && $0.0.status != .active { return false }
            return $0.1 < $1.1
        }).first?.0,
              let day = selected.day,
              let departure = selected.trainDeparture,
              let target = selected.effectiveTargetArrival else { return nil }
        let calculated = Calculation.run(selected)
        let hasForwardPlan = selected.status == .ready && selected.isSimpleJourney && !selected.activities.isEmpty
        return WidgetPlanSnapshot(planID: selected.id, day: day,
                                  station: selected.stationPlace, departure: departure,
                                  targetArrival: target, latestStart: calculated.latestStart,
                                  plannedStart: hasForwardPlan ? selected.plannedStart : nil,
                                  bufferedArrival: hasForwardPlan ? calculated.buffered : nil)
    }
}

enum WidgetSnapshotStore {
    static let suiteName = "group.com.lvyouxucn.app"
    static let key = "LvYouXu.widget.plan.v1"
    static let widgetKind = "LvYouXuJourneyWidget"

    @discardableResult static func update(_ plans: [Plan]) -> Bool {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil,
              let shared = UserDefaults(suiteName: suiteName) else { return false }
        do {
            if let snapshot = WidgetPlanSnapshot.preferred(from: plans) {
                shared.set(try JSONEncoder().encode(snapshot), forKey: key)
            } else {
                shared.removeObject(forKey: key)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return true
        } catch { return false }
    }
}
