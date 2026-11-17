import Foundation
import Combine
import UserNotifications

enum ReminderKind: String, Equatable {
    case plannedStart, latestStart, targetArrival

    var message: String {
        switch self {
        case .plannedStart: "到了你设置的计划开始时间，请打开行程核对。"
        case .latestStart: "到了计算出的最晚开始时间，请核对当前安排。"
        case .targetArrival: "到了你设置的目标到站时间。"
        }
    }
}

struct ReminderMoment {
    let kind: ReminderKind
    let date: Date
}

enum ReminderSchedule {
    static func candidates(for plan: Plan, now: Date = Date()) -> [ReminderMoment] {
        guard !plan.isDemo, [.ready, .active].contains(plan.status), plan.day != nil,
              PlanCompletion.missingItems(in: plan).isEmpty else { return [] }
        let target = plan.effectiveTargetArrival
        let latest = Calculation.run(plan).latestStart
        let options: [(ReminderKind, Int?)] = plan.status == .active
            ? [(.targetArrival, target)]
            : [(.plannedStart, plan.plannedStart), (.latestStart, latest), (.targetArrival, target)]
        var seen = Set<Int>()
        return options.compactMap { kind, minute in
            guard let minute, seen.insert(minute).inserted,
                  let date = minutesDate(plan.day, minute), date > now else { return nil }
            return ReminderMoment(kind: kind, date: date)
        }.sorted { $0.date < $1.date }
    }
}

@MainActor
final class ReminderCenter: ObservableObject {
    static let shared = ReminderCenter()
    @Published private(set) var enabledPlanID: UUID?
    @Published private(set) var permission = "未询问"
    @Published private(set) var scheduledCount = 0
    @Published private(set) var message: String?

    private let preferenceKey = "LvYouXu.reminder.enabledPlanID"
    private let center = UNUserNotificationCenter.current()
    private let requestPrefix = "LvYouXu.reminder."
    private var pendingSync: Task<Void, Never>?

    private init() {
        enabledPlanID = UserDefaults.standard.string(forKey: preferenceKey).flatMap(UUID.init(uuidString:))
    }

    func refreshPermission() async {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: permission = "已允许"
        case .denied: permission = "未允许"
        case .notDetermined: permission = "未询问"
        @unknown default: permission = "未允许"
        }
    }

    func enable(_ plan: Plan, allPlans: [Plan]) async {
        guard !plan.isDemo, [.ready, .active].contains(plan.status),
              PlanCompletion.missingItems(in: plan).isEmpty else {
            message = "请先补全并保存这份计划，再开启提醒。"
            return
        }
        await refreshPermission()
        if permission == "未询问" {
            do { _ = try await center.requestAuthorization(options: [.alert, .badge, .sound]) }
            catch { message = "通知授权未完成，可稍后重试。"; return }
            await refreshPermission()
        }
        guard permission == "已允许" else {
            message = "通知权限未允许。可到系统设置中开启，计划仍可正常使用。"
            return
        }
        enabledPlanID = plan.id
        UserDefaults.standard.set(plan.id.uuidString, forKey: preferenceKey)
        await enqueueReconcile(plans: allPlans)
    }

    func disable(allPlans: [Plan]) async {
        enabledPlanID = nil
        UserDefaults.standard.removeObject(forKey: preferenceKey)
        await enqueueReconcile(plans: allPlans)
    }

    func enqueueReconcile(plans: [Plan]) async {
        let previous = pendingSync
        let task = Task { @MainActor in
            await previous?.value
            await reconcile(plans: plans)
        }
        pendingSync = task
        await task.value
    }

    private func reconcile(plans: [Plan]) async {
        await refreshPermission()
        let pending = await center.pendingNotificationRequests()
        let owned = pending.map(\.identifier).filter { $0.hasPrefix(requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: owned)
        center.removeDeliveredNotifications(withIdentifiers: owned)
        scheduledCount = 0
        guard let id = enabledPlanID else { message = nil; return }
        guard let plan = plans.first(where: { $0.id == id }),
              ![.finished, .ended, .archived, .draft].contains(plan.status) else {
            enabledPlanID = nil
            UserDefaults.standard.removeObject(forKey: preferenceKey)
            message = nil
            return
        }
        guard permission == "已允许" else {
            message = "通知权限未允许。请到系统设置中开启后重试。"
            return
        }
        let moments = ReminderSchedule.candidates(for: plan)
        guard !moments.isEmpty else { message = "没有需要安排的未来提醒。"; return }
        var errors = 0
        for moment in moments {
            let content = UNMutableNotificationContent()
            content.title = "行程时间提醒"
            content.body = moment.kind.message
            content.sound = .default
            var parts = chinaCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: moment.date)
            parts.timeZone = chinaZone
            let request = UNNotificationRequest(identifier: "\(requestPrefix)\(id.uuidString).\(moment.kind.rawValue)",
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            do { try await center.add(request); scheduledCount += 1 }
            catch { errors += 1 }
        }
        message = errors > 0 ? "计划已保存，提醒更新失败，请重试。" : nil
    }
}
