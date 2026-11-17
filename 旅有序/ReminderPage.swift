import SwiftUI

struct ReminderPage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.openURL) private var openURL
    @ObservedObject private var reminders = ReminderCenter.shared
    let id: UUID

    @State private var working = false
    @State private var confirmReplace = false

    var body: some View {
        PageScroll {
            if let plan = store.plan(id), !plan.isDemo {
                PageTitle(title: "行程提醒", subtitle: plan.displayTitle)
                WayCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("是否需要提醒", isOn: Binding(
                            get: { reminders.enabledPlanID == id },
                            set: { enabled in change(enabled, plan: plan) }
                        ))
                        .font(.headline)
                        .disabled(working || plan.status == .draft || [.finished, .ended, .archived].contains(plan.status))
                        Text("开启后，可在计划开始、最晚开始和目标到站时收到提醒。系统可能延迟或不显示通知，请自行留意时间。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if plan.isSimpleJourney {
                            Text(plan.activities.isEmpty
                                 ? "这份简化行程会提醒建议最晚出发和建议到站；过去的时刻不会补发。"
                                 : "这份中途行程会提醒计划出发、最晚出发和建议到站；过去的时刻不会补发。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if plan.status == .draft {
                    IssueBanner(text: "请先补全并保存这份计划，再开启提醒。")
                }
                WayCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("通知权限：\(reminders.permission)").font(.headline)
                        Text(reminders.enabledPlanID == id ? "已安排\(reminders.scheduledCount)条未来提醒" : "提醒未开启，仍可使用全部规划功能。")
                            .font(.body)
                        if let message = reminders.message { Text(message).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
                if reminders.permission == "未允许" {
                    WayButton(title: "前往系统设置", filled: false) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                if reminders.enabledPlanID == id {
                    WayButton(title: "重新安排提醒", filled: false) { perform { await reminders.enqueueReconcile(plans: store.plans) } }
                }
                Text("提醒仅作辅助，不代表已到站或已完成行程。锁屏通知默认不显示地点和行程名称。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                IssueBanner(text: "未找到可设置提醒的计划。")
            }
        }
        .navigationTitle("提醒设置").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("改为提醒此计划？原计划的提醒将关闭。", isPresented: $confirmReplace) {
            Button("改为提醒此计划") {
                if let plan = store.plan(id) { perform { await reminders.enable(plan, allPlans: store.plans) } }
            }
            Button("取消", role: .cancel) {}
        }
        .task { await reminders.refreshPermission() }
    }

    private func change(_ enabled: Bool, plan: Plan) {
        if enabled && reminders.enabledPlanID != nil && reminders.enabledPlanID != id {
            confirmReplace = true
        } else if enabled {
            perform { await reminders.enable(plan, allPlans: store.plans) }
        } else {
            perform { await reminders.disable(allPlans: store.plans) }
        }
    }

    private func perform(_ action: @escaping () async -> Void) {
        working = true
        Task { await action(); working = false }
    }
}
