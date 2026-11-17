import Foundation

enum CompletionDestination: Equatable {
    case basics
    case activity(Int)
    case finalTravel
}

struct CompletionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let destination: CompletionDestination
}

enum PlanCompletion {
    static func missingItems(in plan: Plan) -> [CompletionItem] {
        var items: [CompletionItem] = []
        func add(_ id: String, _ title: String, _ detail: String, _ destination: CompletionDestination) {
            items.append(CompletionItem(id: id, title: title, detail: detail, destination: destination))
        }
        if plan.isSimpleJourney {
            if plan.day == nil { add("day", "返程日期", "选择火车出发的日期。", .basics) }
            if plan.startPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("startPlace", "从哪里出发", "填写前往车站的起点，例如酒店。", .basics) }
            if plan.stationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("stationPlace", "乘车站", "填写车票上的车站名称。", .basics) }
            if plan.trainDeparture == nil { add("trainDeparture", "列车发车时间", "按照车票填写发车时间，例如17:30。", .basics) }
            else if plan.effectiveTargetArrival == nil { add("arrivalLead", "提前到站时间", "提前到站时间不能晚于发车时间。", .basics) }
            if !plan.activities.isEmpty && !(0..<1440).contains(plan.plannedStart ?? -1) {
                add("plannedStart", "计划出发时间", "选一个从出发地点开始中途行程的时间。", .basics)
            }
            if plan.finalTravel == nil || !(1...360).contains(plan.finalTravel ?? 0) {
                add("travel", "去车站预计用时", plan.activities.isEmpty ? "估计从起点到车站要多少分钟。" : "估计从最后一站到车站要多少分钟。", .basics)
            }
            for (index, activity) in plan.activities.enumerated() {
                let name = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty { add("activity-\(index)-title", "第\(index + 1)项中途行程", "写下这一步要做什么。", .basics) }
                if activity.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    add("activity-\(index)-place", "中途地点", "填写这项活动在哪里进行。", .basics)
                }
                if !(1...360).contains(activity.duration ?? 0) {
                    add("activity-\(index)-duration", "停留时长", "填写预计停留的分钟数，范围为1到360分钟。", .basics)
                }
                if !activity.samePlace && !(1...360).contains(activity.incomingMinutes ?? 0) {
                    add("activity-\(index)-leg", "去\(name.isEmpty ? "中途地点" : name)的交通时间", "估计从上一处到这里要多少分钟。", .basics)
                }
            }
            return items
        }
        if plan.day == nil { add("day", "返程日期", "选择实际返程的日期。", .basics) }
        if plan.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("city", "所在城市", "填写返程当天所在城市。", .basics) }
        if plan.startPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("startPlace", "从哪里开始", "填写开始当天行程的地点。", .basics) }
        if plan.stationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { add("stationPlace", "乘车站", "填写你要去的车站。", .basics) }
        if plan.plannedStart == nil { add("plannedStart", "计划开始时间", "选择准备开始当天行程的时间。", .basics) }
        if plan.targetArrival == nil { add("targetArrival", "目标到站时间", "选择希望到达车站的时间。", .basics) }
        if let start = plan.plannedStart, let target = plan.targetArrival,
           target <= start || plan.trainDeparture.map({ target >= $0 }) == true {
            add("arrivalOrder", "核对目标到站时间", "目标应晚于计划开始，且早于填写的发车时间。", .basics)
        }
        if plan.activities.isEmpty { add("activities", "添加活动", "先添加退房、游玩或取行李等当天要做的事。", .activity(0)) }
        for (index, activity) in plan.activities.enumerated() {
            let name = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "第\(index + 1)项活动" : activity.title
            if activity.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add("activity-\(index)-title", "第\(index + 1)项活动名称", "写下这一步要做什么。", .activity(index))
            }
            if activity.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                add("activity-\(index)-place", "\(name)的地点", "填写这项活动在哪里进行。", .activity(index))
            }
            if activity.duration == nil || !(1...360).contains(activity.duration ?? 0) {
                add("activity-\(index)-duration", "\(name)的停留时长", "填写预计需要的分钟数，范围为1–360分钟。", .activity(index))
            }
            if !activity.samePlace && (activity.incomingMinutes == nil || !(1...360).contains(activity.incomingMinutes ?? 0)) {
                add("activity-\(index)-leg", "去\(name)的交通时间", "自行估计到这个地点要用多少分钟；不确定可先存草稿。", .activity(index))
            }
        }
        if !plan.finalSamePlace && (plan.finalTravel == nil || !(1...360).contains(plan.finalTravel ?? 0)) {
            add("finalTravel", "去车站的交通时间", "自行估计从最后一处地点到车站需要多少分钟。", .finalTravel)
        }
        return items
    }
}
