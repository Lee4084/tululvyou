import SwiftUI

struct MyJourneyRecordsPage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.colorScheme) private var scheme
    @State private var toDelete: UUID? = nil
    @State private var issue: String? = nil
    let go: (Route) -> Void

    private var history: [Plan] {
        sorted(store.plans.filter { [.finished, .ended, .archived].contains($0.status) && !$0.isDemo })
    }
    private var current: [Plan] {
        sorted(store.plans.filter { [.draft, .ready, .active].contains($0.status) && !$0.isDemo })
    }

    var body: some View {
        PageScroll {
            PageTitle(title: "我的旅程记录", subtitle: "本机保存的计划与历史记录，都可以在这里查看。")
            if let issue { IssueBanner(text: issue) }
            if history.isEmpty && current.isEmpty {
                WayCard(tint: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath").font(.title2)
                        Text("还没有旅程记录").font(.headline)
                        Text("新建返程计划后，会显示在这里。")
                            .font(.body).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("历史记录").font(.title3.bold()).padding(.top, 8)
                if history.isEmpty {
                    WayCard { Text("还没有已完成或提前结束的旅程。")
                        .font(.body).foregroundStyle(.secondary) }
                }
                ForEach(history) { plan in journeyCard(plan) }

                if !current.isEmpty {
                    Text("当前计划").font(.title3.bold()).padding(.top, 12)
                    ForEach(current) { plan in journeyCard(plan) }
                }
            }
        }
        .navigationTitle("我的旅程记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("删除此计划及关联记录？此操作不可撤销。",
               isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("删除旅程", role: .destructive) {
                if let id = toDelete, !store.remove(id) {
                    issue = store.error ?? "删除未完成，数据仍保留，请重试。"
                } else { issue = nil }
                toDelete = nil
            }
            Button("取消", role: .cancel) { toDelete = nil }
        } message: {
            Text("这趟旅程及其本机记录和提醒会一并移除；已经分享出去的文件不会删除。")
        }
    }

    private func sorted(_ plans: [Plan]) -> [Plan] {
        plans.sorted { ($0.day ?? .distantPast) > ($1.day ?? .distantPast) }
    }

    private func journeyCard(_ plan: Plan) -> some View {
        WayCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(plan.displayTitle).font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StatusBadge(title: plan.status.label, warning: plan.status == .ended)
                }
                Text("\(dayText(plan.day)) · \(plan.startPlace.isEmpty ? "出发地待填" : plan.startPlace) → \(plan.stationPlace.isEmpty ? "车站待填" : plan.stationPlace)")
                    .font(.body).foregroundStyle(.secondary)
                if [.finished, .ended].contains(plan.status) {
                    Text(plan.actualArrival.map { "实际到站 " + timeText($0) } ?? "未记录实际到站时间")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button("查看") { go([.finished, .ended, .archived].contains(plan.status) ? .record(plan.id) : .timeline(plan.id)) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Wayfinding.raised(scheme == .dark), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("查看旅程：\(plan.displayTitle)")
                    if plan.status != .active {
                        Button("删除旅程", role: .destructive) { toDelete = plan.id }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Wayfinding.raised(scheme == .dark), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("删除旅程：\(plan.displayTitle)")
                    }
                }
                if plan.status == .active {
                    Text("进行中的旅程请先完成或提前结束，再删除。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}
