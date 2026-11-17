import Foundation
import Combine

let chinaZone = TimeZone(identifier: "Asia/Shanghai")!
var chinaCalendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = chinaZone; return c }
func timeText(_ date: Date?) -> String {
    guard let date else { return "待补全" }
    let f = DateFormatter(); f.timeZone = chinaZone; f.dateFormat = "HH:mm"; return f.string(from: date)
}
func dayText(_ date: Date?) -> String {
    guard let date else { return "日期待填" }
    let f = DateFormatter(); f.timeZone = chinaZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
}
func minutesDate(_ day: Date?, _ minute: Int?) -> Date? {
    guard let day, let minute else { return nil }
    return chinaCalendar.startOfDay(for: day).addingTimeInterval(TimeInterval(minute * 60))
}
func minuteOfDay(_ date: Date?) -> Int? {
    guard let date else { return nil }
    let c = chinaCalendar.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

enum PlanStatus: String, Codable { case draft, ready, active, finished, ended, archived
    var label: String { switch self { case .draft: "草稿"; case .ready: "可开始"; case .active: "进行中"; case .finished: "已完成"; case .ended: "提前结束"; case .archived: "已归档" } }
}
enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case checkout, storeBag, sightseeing, meal, collectBag, custom
    var id: String { rawValue }
    var label: String { switch self { case .checkout: "退房"; case .storeBag: "寄存行李"; case .sightseeing: "游玩"; case .meal: "用餐"; case .collectBag: "取行李"; case .custom: "自定义" } }
}
struct Activity: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var kind: ActivityKind = .custom
    var place = ""
    var duration: Int? = nil
    var incomingMinutes: Int? = nil
    var samePlace = false
    var travelMode = "步行"
    var sourceNote = ""
    var required = true
    var allowShorten = false
    var minDuration: Int? = nil
    var fixedStart: Int? = nil
    var latestFinish: Int? = nil
    var predecessorIDs: [UUID] = []
}
enum ExecutionPhase: String, Codable { case between, travel, atActivity, activity, finalTravel, needsUpdate, station }
struct Execution: Codable {
    var phase: ExecutionPhase = .between
    var index = 0
    var startedAt: Date
    var phaseStartedAt: Date? = nil
    var expectedEnd: Date? = nil
    var remainingMinutes: Int? = nil
    var suspendedPhase: ExecutionPhase? = nil
    var lastEventAt: Date? = nil
    var actualArrival: Date? = nil

    func updatingRemaining(_ minutes: Int, now: Date) -> Execution? {
        guard (1...360).contains(minutes) else { return nil }
        var updated = self
        if phase == .needsUpdate {
            guard let suspendedPhase, [.travel, .activity, .finalTravel].contains(suspendedPhase) else { return nil }
            updated.phase = suspendedPhase
            updated.suspendedPhase = nil
        } else {
            guard [.travel, .activity, .finalTravel].contains(phase) else { return nil }
        }
        updated.remainingMinutes = minutes
        updated.expectedEnd = now.addingTimeInterval(TimeInterval(minutes * 60))
        updated.lastEventAt = now
        return updated
    }
}
struct Plan: Identifiable, Codable {
    var id = UUID()
    var revision = 1
    var title = ""
    var day: Date? = nil
    var city = ""
    var startPlace = ""
    var stationPlace = ""
    var plannedStart: Int? = nil
    var targetArrival: Int? = nil
    var trainDeparture: Int? = nil
    var arrivalLeadMinutes: Int? = 60
    var simpleJourney: Bool? = true
    var trainLabel = ""
    var buffer = 20
    var activities: [Activity] = []
    var finalTravel: Int? = nil
    var finalSamePlace = false
    var status: PlanStatus = .draft
    var isDemo = false
    var execution: Execution? = nil
    var changeNotes: [String] = []
    var actualArrival: Date? = nil
    var notes = ""
    var displayTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        if isSimpleJourney && !stationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "前往\(stationPlace)" }
        return "未命名返程"
    }
    var isSimpleJourney: Bool { simpleJourney != false }
    var effectiveTargetArrival: Int? {
        guard isSimpleJourney else { return targetArrival }
        guard let trainDeparture else { return nil }
        let target = trainDeparture - (arrivalLeadMinutes ?? 60)
        return target >= 0 ? target : nil
    }
    static let demoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static var demo: Plan {
        var p = Plan(); p.id = demoID; p.title = "返程前再逛一处"; p.day = chinaCalendar.date(from: DateComponents(year: 2026, month: 11, day: 20)); p.city = "示例城市"; p.startPlace = "河畔展馆"; p.stationPlace = "城市东站"; p.plannedStart = 760; p.targetArrival = 960; p.trainDeparture = 1000; p.buffer = 20; p.finalTravel = 45; p.status = .ready; p.isDemo = true; p.simpleJourney = false
        p.activities = [Activity(title: "逛展", kind: .sightseeing, place: "河畔展馆", duration: 60, incomingMinutes: 0, samePlace: true, required: false, allowShorten: true, minDuration: 30), Activity(title: "取行李", kind: .collectBag, place: "住过的酒店", duration: 15, incomingMinutes: 35, sourceNote: "我自行估计", required: true)]
        return p
    }
}
struct Calculation {
    var physical: Int? = nil
    var buffered: Int? = nil
    var margin: Int? = nil
    var latestStart: Int? = nil
    var issues: [String] = []
    var stops: [(start: Int, end: Int, wait: Int)] = []
    var complete: Bool { latestStart != nil || buffered != nil }
    static func run(_ plan: Plan, start override: Int? = nil) -> Calculation {
        var result = Calculation()
        if plan.isSimpleJourney {
            guard let target = plan.effectiveTargetArrival else {
                result.issues.append("请填写列车发车时间，并选择提前到站时间。")
                return result
            }
            guard let travel = plan.finalTravel, (1...360).contains(travel) else {
                result.issues.append("请填写去车站预计用时，不会把空值当成0。")
                return result
            }
            var stopMinutes = 0
            for activity in plan.activities {
                guard !activity.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !activity.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let duration = activity.duration, (1...360).contains(duration),
                      activity.samePlace || (1...360).contains(activity.incomingMinutes ?? 0) else {
                    result.issues.append("请补全中途行程的停留与交通时间，不会把空值当成0。")
                    return result
                }
                stopMinutes += duration + (activity.samePlace ? 0 : (activity.incomingMinutes ?? 0))
            }
            let latest = target - stopMinutes - travel - plan.buffer
            if latest < 0 {
                result.issues.append("当天时间不足，请调整发车时间、提前到站时间或交通用时。")
            } else {
                result.latestStart = latest
            }
            if let start = override ?? plan.plannedStart {
                guard (0..<1440).contains(start) else {
                    result.issues.append("计划出发时间不在返程当天，请重新选择。")
                    return result
                }
                if start >= target {
                    result.issues.append("计划出发时间需早于建议到站时间，请调整。")
                }
                var cursor = start
                for activity in plan.activities {
                    cursor += activity.samePlace ? 0 : (activity.incomingMinutes ?? 0)
                    let begin = cursor
                    cursor += activity.duration ?? 0
                    result.stops.append((begin, cursor, 0))
                }
                let physical = cursor + travel
                result.physical = physical
                result.buffered = physical + plan.buffer
                result.margin = target - physical - plan.buffer
                if let train = plan.trainDeparture, physical >= train {
                    result.issues.append("按填写时间预计到站已不早于列车发车，请调整行程。")
                }
                if physical + plan.buffer >= 1440 {
                    result.issues.append("首版只支持同一日的返程安排，请调整计划出发时间或行程时长。")
                }
            }
            return result
        }
        guard let start = override ?? plan.plannedStart, let target = plan.targetArrival, !plan.activities.isEmpty else { result.issues.append("待补全，暂不能计算完整行程。"); return result }
        if start >= target { result.issues.append("目标到站需晚于计划开始，并早于已填写的列车发车时间。") }
        if let train = plan.trainDeparture, target >= train { result.issues.append("目标到站需晚于计划开始，并早于已填写的列车发车时间。") }
        if plan.activities.contains(where: { $0.duration == nil || ($0.incomingMinutes == nil && !$0.samePlace) }) || (plan.finalTravel == nil && !plan.finalSamePlace) {
            result.issues.append("请先补全交通时间，不会把空值当成0。")
            return result
        }
        var cursor = start
        for activity in plan.activities {
            cursor += activity.samePlace ? 0 : (activity.incomingMinutes ?? 0)
            let arrival = cursor
            let wait = max(0, (activity.fixedStart ?? cursor) - cursor)
            if let fixed = activity.fixedStart, arrival > fixed { result.issues.append("预约开始已错过，请核实是否仍可参加。") }
            cursor += wait
            let begin = cursor
            cursor += activity.duration ?? 0
            if let latest = activity.latestFinish, cursor > latest { result.issues.append("超过最晚完成时间\(cursor - latest)分钟") }
            result.stops.append((begin, cursor, wait))
        }
        cursor += plan.finalSamePlace ? 0 : (plan.finalTravel ?? 0)
        result.physical = cursor; result.buffered = cursor + plan.buffer; result.margin = target - cursor - plan.buffer
        if cursor + plan.buffer >= 1440 { result.issues.append("首版只支持同一日的返程安排。") }
        var latest = target - plan.buffer - (plan.finalSamePlace ? 0 : (plan.finalTravel ?? 0))
        var feasible = true
        for activity in plan.activities.reversed() {
            if let limit = activity.latestFinish { latest = min(latest, limit) }
            if let fixed = activity.fixedStart {
                if fixed + (activity.duration ?? 0) > latest { feasible = false }
                latest = fixed
            } else { latest -= activity.duration ?? 0 }
            latest -= activity.samePlace ? 0 : (activity.incomingMinutes ?? 0)
        }
        if feasible && latest >= 0 { result.latestStart = latest }
        else { result.issues.append("当前条件下没有可行的当日开始时间。") }
        return result
    }
}
func clockText(_ minute: Int?) -> String {
    guard let minute, minute >= 0, minute < 1440 else { return "待补全" }
    return String(format: "%02d:%02d", minute / 60, minute % 60)
}

final class PlanStore: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var demoOverride: Plan? = nil
    @Published var error: String? = nil
    @Published var widgetIssue: String? = nil
    private let key = "LvYouXu.plans.v1"
    init() {
        #if DEBUG
        let launchArguments = ProcessInfo.processInfo.arguments
        if launchArguments.contains("--ui-testing-journeys") {
            func sample(_ title: String, _ status: PlanStatus, _ daysAgo: Int) -> Plan {
                var plan = Plan()
                plan.title = title
                plan.day = chinaCalendar.date(byAdding: .day, value: -daysAgo, to: Date())
                plan.startPlace = "酒店"
                plan.stationPlace = "上海虹桥站"
                plan.trainDeparture = 17 * 60 + 30
                plan.finalTravel = 45
                plan.targetArrival = plan.effectiveTargetArrival
                plan.status = status
                return plan
            }
            plans = [sample("当前旅程", .active, 0), sample("待出发的返程", .ready, 0),
                     sample("已完成的返程", .finished, 1), sample("提前结束的返程", .ended, 2)]
            refreshWidget()
            return
        }
        if launchArguments.contains("--ui-testing-stale-final") {
            let now = Date()
            var sample = Plan()
            sample.day = now
            sample.startPlace = "酒店"
            sample.stationPlace = "上海虹桥站"
            sample.trainDeparture = 17 * 60 + 30
            sample.targetArrival = sample.effectiveTargetArrival
            sample.finalTravel = 45
            sample.status = .active
            var execution = Execution(startedAt: now.addingTimeInterval(-3600))
            execution.phase = .finalTravel
            execution.phaseStartedAt = now.addingTimeInterval(-3600)
            execution.expectedEnd = now.addingTimeInterval(-60)
            sample.execution = execution
            plans = [sample]
            refreshWidget()
            return
        }
        if launchArguments.contains("--ui-testing-personal") {
            var sample = Plan()
            sample.title = "提前结束的返程"
            sample.day = Date()
            sample.startPlace = "酒店"
            sample.stationPlace = "车站"
            sample.status = .ended
            plans = [sample]
            refreshWidget()
            return
        }
        if launchArguments.contains("--ui-testing-route") || launchArguments.contains("--ui-testing-route-stops") || launchArguments.contains("--ui-testing-reminder") {
            var sample = Plan()
            sample.day = launchArguments.contains("--ui-testing-reminder")
                ? chinaCalendar.date(byAdding: .day, value: 1, to: Date())
                : Date()
            sample.startPlace = "上海人民广场"
            sample.stationPlace = "上海虹桥站"
            sample.trainDeparture = 17 * 60 + 30
            sample.finalTravel = 45
            sample.targetArrival = sample.effectiveTargetArrival
            if launchArguments.contains("--ui-testing-route-stops") {
                sample.plannedStart = 14 * 60
                sample.activities = [Activity(title: "参观博物馆", kind: .sightseeing,
                                              place: "上海博物馆", duration: 30, incomingMinutes: 15)]
            }
            sample.status = .ready
            plans = [sample]
            refreshWidget()
            return
        }
        #endif
        load()
    }
    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { plans = []; refreshWidget(); return }
        do {
            plans = try JSONDecoder().decode([Plan].self, from: data).map { saved in
                var plan = saved
                if plan.simpleJourney == nil && !plan.isDemo {
                    plan.simpleJourney = true
                    plan.arrivalLeadMinutes = 60
                    plan.plannedStart = nil
                    plan.targetArrival = plan.effectiveTargetArrival
                }
                if plan.status == .ready {
                    let calculation = Calculation.run(plan)
                    if !PlanCompletion.missingItems(in: plan).isEmpty || !calculation.complete || !calculation.issues.isEmpty {
                        plan.status = .draft
                    }
                }
                return plan
            }
            let snapshot = plans
            refreshWidget()
            Task { @MainActor in await ReminderCenter.shared.enqueueReconcile(plans: snapshot) }
        }
        catch { self.error = "本地数据暂时无法读取，请重试。" }
    }
    @discardableResult func save(_ plan: Plan) -> Bool {
        if plan.isDemo { demoOverride = plan; return true }
        var copy = plans
        if let i = copy.firstIndex(where: { $0.id == plan.id }) { copy[i] = plan } else { copy.append(plan) }
        do {
            let data = try JSONEncoder().encode(copy)
            UserDefaults.standard.set(data, forKey: key)
            plans = copy
            error = nil
            refreshWidget()
            let snapshot = copy
            Task { @MainActor in await ReminderCenter.shared.enqueueReconcile(plans: snapshot) }
            return true
        }
        catch { self.error = "保存失败，输入仍保留，请重试。"; return false }
    }
    @discardableResult func remove(_ id: UUID) -> Bool {
        guard let plan = plans.first(where: { $0.id == id }) else {
            error = "这趟旅程已不存在，请刷新列表。"
            return false
        }
        guard plan.status != .active else {
            error = "进行中的旅程请先完成或提前结束，再删除。"
            return false
        }
        return persist(plans.filter { $0.id != id })
    }
    @discardableResult func removeAll() -> Bool { persist([]) }
    @discardableResult private func persist(_ next: [Plan]) -> Bool {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(next), forKey: key)
            plans = next
            error = nil
            refreshWidget()
            Task { @MainActor in await ReminderCenter.shared.enqueueReconcile(plans: next) }
            return true
        } catch {
            self.error = "删除未完成，数据仍保留，请重试。"
            return false
        }
    }
    var active: Plan? { plans.first { $0.status == .active } }
    func plan(_ id: UUID) -> Plan? { if id == Plan.demoID { return demoOverride ?? Plan.demo }; return plans.first { $0.id == id } }
    func refreshWidget() {
        widgetIssue = WidgetSnapshotStore.update(plans) ? nil : "小组件暂未同步，请更新 App 后再试；若仍未显示，请联系支持。"
    }
}

func executionEstimate(_ p: Plan, _ ex: Execution, now: Int) -> Calculation {
    guard let target = p.targetArrival else { return Calculation(issues: ["待补全，暂不能计算完整行程。"]) }
    guard ex.index >= 0, ex.index <= p.activities.count else { return Calculation(issues: ["行程阶段异常，请重新打开计划。"] ) }
    let phase = ex.phase
    if let end = ex.expectedEnd, end < Date(), [.travel, .activity, .finalTravel].contains(phase) { return Calculation(issues: ["请更新剩余时间"]) }
    var cursor = now
    var startIndex = ex.index
    if phase == .travel || phase == .activity || phase == .finalTravel {
        guard let end = ex.expectedEnd, let minute = minuteOfDay(end) else { return Calculation(issues: ["请更新剩余时间"]) }
        cursor = max(now, minute)
        if phase == .travel, p.activities.indices.contains(ex.index) { cursor += p.activities[ex.index].duration ?? 0; startIndex += 1 }
        if phase == .activity { startIndex += 1 }
        if phase == .finalTravel { let physical = cursor; return Calculation(physical: physical, buffered: physical + p.buffer, margin: target - physical - p.buffer) }
    } else if phase == .atActivity, p.activities.indices.contains(ex.index) {
        cursor += p.activities[ex.index].duration ?? 0; startIndex += 1
    }
    guard startIndex <= p.activities.count else { return Calculation(issues: ["行程阶段异常，请重新打开计划。"] ) }
    for i in startIndex..<p.activities.count {
        let a = p.activities[i]
        guard let duration = a.duration, a.samePlace || a.incomingMinutes != nil else { return Calculation(issues: ["请先补全交通时间，不会把空值当成0。"]) }
        cursor += a.samePlace ? 0 : (a.incomingMinutes ?? 0)
        cursor = max(cursor, a.fixedStart ?? cursor)
        cursor += duration
    }
    guard p.finalSamePlace || p.finalTravel != nil else { return Calculation(issues: ["请先补全交通时间，不会把空值当成0。"]) }
    cursor += p.finalSamePlace ? 0 : (p.finalTravel ?? 0)
    return Calculation(physical: cursor, buffered: cursor + p.buffer, margin: target - cursor - p.buffer)
}
