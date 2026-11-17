import SwiftUI
import UserNotifications
import UIKit

struct PlansPage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.colorScheme) private var scheme
    let go: (Route) -> Void
    @State private var filter = "今天"
    @State private var toDelete: UUID? = nil
    private let filters = ["今天", "未来", "草稿", "已过期"]
    private var shown: [Plan] {
        let today = chinaCalendar.startOfDay(for: Date())
        return store.plans.filter { plan in
            if plan.status == .finished || plan.status == .ended || plan.status == .archived { return false }
            if plan.status == .draft { return filter == "草稿" }
            guard let day = plan.day else { return filter == "草稿" }
            let date = chinaCalendar.startOfDay(for: day)
            return filter == "今天" ? date == today : filter == "未来" ? date > today : filter == "已过期" ? date < today : false
        }
    }
    var body: some View {
        PageScroll {
            Text("途鹿旅游").font(.headline)
            PageTitle(title: "计划", subtitle: "安排有序，旅行从容。")
            NewPlanButton { go(.create) }
            if let error = store.error { ErrorCard(message: error) { store.load() } }
            if let active = store.active {
                Button { go(.timeline(active.id)) } label: { WayCard(tint: true) { Label("继续当前行程", systemImage: "location.north.fill").font(.headline) } }.buttonStyle(.plain)
            }
            Text("全部计划").font(.title3.bold()).padding(.top, 10)
            Picker("筛选", selection: $filter) { ForEach(filters, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            if shown.isEmpty {
                WayCard { VStack(alignment: .leading, spacing: 8) { Image(systemName: "calendar.badge.plus").font(.title2); Text(store.plans.isEmpty ? "还没有计划，从最后半天开始安排吧。" : "未找到符合条件的计划").font(.body) } }
            } else {
                ForEach(shown) { plan in
                    Button { go(.timeline(plan.id)) } label: { planCard(plan) }.buttonStyle(.plain)
                        .contextMenu {
                            Button("复制为新计划") { go(.create) }
                            if plan.status != .active {
                                Button("归档") { var p = plan; p.status = .archived; _ = store.save(p) }
                                Button("删除", role: .destructive) { toDelete = plan.id }
                            }
                        }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("删除此计划及关联记录？此操作不可撤销。", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("删除", role: .destructive) { if let id = toDelete { store.remove(id) }; toDelete = nil }
            Button("取消", role: .cancel) { toDelete = nil }
        }
    }
    private func planCard(_ plan: Plan) -> some View {
        let calc = Calculation.run(plan)
        let missing = PlanCompletion.missingItems(in: plan)
        return WayCard(tint: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(dayText(plan.day)).font(.footnote.weight(.semibold)).foregroundStyle(Wayfinding.teal(scheme == .dark)); Spacer(); StatusBadge(title: plan.status.label) }
                Text(plan.displayTitle).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Wayfinding.ink(scheme == .dark))
                Text("\(plan.startPlace) → \(plan.stationPlace)").font(.body).foregroundStyle(Wayfinding.muted(scheme == .dark))
                if plan.isSimpleJourney {
                    if plan.activities.isEmpty {
                        HStack { metric("火车发车", clockText(plan.trainDeparture)); Spacer(); metric("建议最晚出发", clockText(calc.latestStart)) }.padding(.vertical, 8)
                        Text("建议到站 \(clockText(plan.effectiveTargetArrival)) · 已留\(plan.buffer)分钟路上缓冲")
                            .font(.body.weight(.semibold)).foregroundStyle(Wayfinding.teal(scheme == .dark))
                    } else {
                        HStack { metric("计划出发", clockText(plan.plannedStart)); Spacer(); metric("预计到站·含缓冲", clockText(calc.buffered)) }.padding(.vertical, 8)
                        Text(calc.margin.map { $0 >= 0 ? "比建议到站早\($0)分钟" : "比建议到站晚\(-$0)分钟" } ?? "中途时间待补全")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(calc.margin.map { $0 < 0 ? Wayfinding.red(scheme == .dark) : Wayfinding.teal(scheme == .dark) } ?? Wayfinding.amber(scheme == .dark))
                        Text("火车\(clockText(plan.trainDeparture))发车 · 最晚出发参考\(clockText(calc.latestStart))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    HStack { metric("目标到站", clockText(plan.targetArrival)); Spacer(); metric("预计到站 · 含\(plan.buffer)分钟缓冲", clockText(calc.buffered)) }.padding(.vertical, 8)
                    Text(calc.margin.map { $0 > 0 ? "估时余量\($0)分钟" : $0 == 0 ? "恰好到目标，额外余量为0。" : "比目标晚\(-$0)分钟" } ?? "待补全，暂不能计算完整行程。")
                        .font(.body.weight(.semibold)).foregroundStyle(calc.margin.map { $0 < 0 ? Wayfinding.red(scheme == .dark) : Wayfinding.teal(scheme == .dark) } ?? Wayfinding.amber(scheme == .dark))
                }
                if let first = missing.first {
                    Text("还需填写\(first.title)\(missing.count > 1 ? "等\(missing.count)项" : "") · 点开计划查看")
                        .font(.subheadline).foregroundStyle(Wayfinding.amber(scheme == .dark))
                }
            }
        }
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(title).font(.footnote).foregroundStyle(.secondary); ValueText(value: value) } }
}

struct ActivePage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.colorScheme) private var scheme
    let go: (Route) -> Void
    @State private var confirm: String? = nil
    @State private var showRemainingSheet = false
    private var readyToday: [Plan] {
        let today = chinaCalendar.startOfDay(for: Date())
        return store.plans.filter {
            $0.status == .ready && $0.day.map { chinaCalendar.startOfDay(for: $0) == today } == true
        }
    }
    var body: some View {
        PageScroll {
            PageTitle(title: "进行中", subtitle: "当前行程与过往记录，都在这里。")
            if let plan = store.active { activeContent(plan) }
            else {
                WayCard(tint: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "figure.walk.motion").font(.title2)
                        Text("今天还没有进行中的行程").font(.headline)
                        Text("准备好后，从下方选择今天的计划开始。")
                            .font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            if !readyToday.isEmpty {
                Text("今天可开始").font(.title3.bold()).padding(.top, 8)
                ForEach(readyToday) { plan in
                    Button { go(.timeline(plan.id)) } label: {
                        WayCard {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.right.circle.fill").font(.title2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(plan.displayTitle).font(.headline)
                                    Text("\(clockText(plan.trainDeparture)) 发车 · \(plan.stationPlace)")
                                        .font(.body).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.subheadline)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
            RecordsSection(go: go)
        }
        .navigationBarHidden(true)
        .alert(confirm ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button("确认") { advance() }
            Button("取消", role: .cancel) { confirm = nil }
        } message: { Text("实际时间将记录为当前中国标准时间。") }
        .sheet(isPresented: $showRemainingSheet) {
            RemainingTimeSheet(onSave: updateRemaining)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    @ViewBuilder private func activeContent(_ plan: Plan) -> some View {
        if let execution = plan.execution {
            let item = execution.index < plan.activities.count ? plan.activities[execution.index] : nil
            let stale = execution.expectedEnd.map { $0 < Date() } == true
            StatusBadge(title: execution.phase == .between ? "待开始下一步" : stale ? "需更新" : execution.phase == .activity ? "正在进行" : "正在前往", warning: stale)
            Text(stale ? "请更新剩余时间" : stageTitle(execution, item)).font(.system(.title, design: .rounded, weight: .bold))
            Text("下一地点 · \(item?.place ?? plan.stationPlace)").foregroundStyle(Wayfinding.muted(scheme == .dark))
            let now = minuteOfDay(Date()) ?? 0
            let estimate = executionEstimate(plan, execution, now: now)
            WayCard(tint: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(execution.phase == .between ? "若现在开始" : "预计到站（含\(plan.buffer)分钟缓冲）").font(.body.weight(.semibold))
                    ValueText(value: stale ? "待更新" : clockText(estimate.buffered), emphasized: true)
                    Text("目标 \(clockText(plan.targetArrival)) · \(estimate.margin.map { $0 >= 0 ? "估时余量\($0)分钟" : "比目标晚\(-$0)分钟" } ?? "待补全")")
                }
            }
            if let item { WayCard { VStack(alignment: .leading, spacing: 8) { Text("下一项").font(.footnote); Text("\(item.title) · \(item.duration.map(String.init) ?? "待补全")分钟").font(.headline); Text(item.required ? "必须保留" : "可选").foregroundStyle(.secondary) } } }
            WayButton(title: stale ? "更新剩余时间" : stageButton(execution, item)) {
                if stale || execution.phase == .needsUpdate { showRemainingSheet = true }
                else { confirm = stageButton(execution, item) }
            }
            if !plan.isSimpleJourney { WayButton(title: "调整剩余安排", filled: false) { go(.adjust(plan.id)) } }
            WayButton(title: "查看时间编排", filled: false) { go(.timeline(plan.id)) }
            Button("提前结束") { confirm = "提前结束" }.foregroundStyle(Wayfinding.red(scheme == .dark)).frame(maxWidth: .infinity, minHeight: 44)
            Text("按填写时长估算，不含实时路况。").font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private func stageTitle(_ ex: Execution, _ item: Activity?) -> String {
        switch ex.phase { case .between: return item == nil ? "开始前往车站" : (item?.samePlace == true ? "开始\(item?.title ?? "活动")" : "开始下一段路程"); case .travel: return "正在前往\(item?.place ?? "下一地点")"; case .atActivity: return "已抵达\(item?.place ?? "活动地点")"; case .activity: return "正在\(item?.title ?? "活动")"; case .finalTravel: return "正在前往车站"; case .needsUpdate: return "请更新剩余时间"; case .station: return "已到车站" }
    }
    private func stageButton(_ ex: Execution, _ item: Activity?) -> String {
        switch ex.phase { case .between: return item == nil ? "开始这段路程" : item?.samePlace == true ? "开始活动" : "开始这段路程"; case .travel: return "已抵达"; case .atActivity: return "开始活动"; case .activity: return "完成活动"; case .finalTravel: return "已到车站"; case .needsUpdate: return "更新剩余时间"; case .station: return "完成" }
    }
    private func updateRemaining(_ minutes: Int) -> Bool {
        guard var plan = store.active, let execution = plan.execution,
              let updated = execution.updatingRemaining(minutes, now: Date()) else { return false }
        plan.execution = updated
        return store.save(plan)
    }
    private func advance() {
        guard var p = store.active, var ex = p.execution else { return }
        let now = Date()
        if confirm == "提前结束" { p.status = .ended; ex.lastEventAt = now; p.execution = ex; _ = store.save(p); confirm = nil; return }
        switch ex.phase {
        case .between:
            if ex.index >= p.activities.count { ex.phase = .finalTravel; ex.expectedEnd = now.addingTimeInterval(TimeInterval((p.finalTravel ?? 0) * 60)) }
            else if p.activities[ex.index].samePlace { ex.phase = .activity; ex.expectedEnd = now.addingTimeInterval(TimeInterval((p.activities[ex.index].duration ?? 0) * 60)) }
            else { ex.phase = .travel; ex.expectedEnd = now.addingTimeInterval(TimeInterval((p.activities[ex.index].incomingMinutes ?? 0) * 60)) }
            ex.phaseStartedAt = now
        case .travel: ex.phase = .atActivity; ex.phaseStartedAt = nil; ex.expectedEnd = nil
        case .atActivity: ex.phase = .activity; ex.phaseStartedAt = now; ex.expectedEnd = now.addingTimeInterval(TimeInterval((p.activities[ex.index].duration ?? 0) * 60))
        case .activity: ex.index += 1; ex.phase = .between; ex.phaseStartedAt = nil; ex.expectedEnd = nil
        case .finalTravel: ex.phase = .station; ex.actualArrival = now; p.actualArrival = now; p.status = p.activities.contains(where: { $0.required && $0.duration == nil }) ? .ended : .finished
        case .needsUpdate, .station: break
        }
        ex.lastEventAt = now; p.execution = ex; _ = store.save(p); confirm = nil
    }
}

private struct RemainingTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = ""
    @State private var issue: String? = nil
    @FocusState private var focused: Bool
    let onSave: (Int) -> Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("请更新剩余时间")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("预计时间已过，尚未确认完成。填写从现在起还需要的分钟数，行程会按当前时刻重新估算。")
                        .font(.body).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        TextField("例如 30", text: $minutes)
                            .keyboardType(.numberPad)
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .focused($focused)
                            .accessibilityLabel("剩余分钟")
                            .onChange(of: minutes) { _, _ in issue = nil }
                        Text("分钟").font(.headline).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    if let issue { Text(issue).font(.subheadline).foregroundStyle(.red) }
                    if let value = Int(minutes), (1...360).contains(value) {
                        Text("按现在估计，这一步约在 \(timeText(Date().addingTimeInterval(TimeInterval(value * 60)))) 结束。")
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    } else {
                        Text("请输入 1 到 360 分钟。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                WayButton(title: "确认更新") {
                    let trimmed = minutes.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let value = Int(trimmed), (1...360).contains(value) else {
                        issue = "请填写 1 到 360 分钟。"
                        return
                    }
                    focused = false
                    if onSave(value) { dismiss() }
                    else { issue = "保存失败，输入仍在这里，请重试。" }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
            .navigationTitle("更新估时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成输入") { focused = false }
                }
            }
        }
    }
}

struct RecordsSection: View {
    @EnvironmentObject private var store: PlanStore
    let go: (Route) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("行程记录").font(.title3.bold()).padding(.top, 12)
            let records = store.plans.filter { [.finished, .ended, .archived].contains($0.status) }
                .sorted { ($0.day ?? .distantPast) > ($1.day ?? .distantPast) }
            if records.isEmpty { WayCard { Text("还没有行程记录").foregroundStyle(.secondary) } }
            ForEach(records) { plan in
                Button { go(.record(plan.id)) } label: {
                    WayCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(plan.displayTitle).font(.headline); Spacer(); StatusBadge(title: plan.status.label) }
                            Text(dayText(plan.day)).font(.body).foregroundStyle(.secondary)
                            Text(plan.actualArrival.map { "实际到站 " + timeText($0) } ?? "未记录实际到站时间")
                                .font(.body)
                        }
                    }
                }.buttonStyle(.plain)
            }
            WayButton(title: "查看演示计划", filled: false) { go(.timeline(Plan.demoID)) }
        }
    }
}

struct ErrorCard: View {
    let message: String
    let retry: () -> Void
    var body: some View { WayCard { HStack { Image(systemName: "exclamationmark.triangle"); Text(message); Spacer(); Button("重试", action: retry) } }.foregroundStyle(.red) }
}

struct BasicPage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss
    let template: Int?
    let editingID: UUID?
    let onSaved: (UUID) -> Void
    @State private var plan = Plan()
    @State private var travelMinutes = ""
    @State private var issue: String? = nil
    @State private var showDiscard = false
    var body: some View {
        PageScroll {
            PageTitle(title: "填写返程信息", subtitle: "照着车票填写，其他时间会自动算好。")
            if let issue { WayCard { Text(issue).foregroundStyle(.red) } }
            WayCard {
                if plan.day == nil {
                    Button("选择返程日期") { plan.day = Date() }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    DatePicker("返程日期", selection: Binding(get: { plan.day ?? Date() }, set: { plan.day = $0 }), displayedComponents: .date)
                }
            }
            field("从哪里出发（如酒店）", text: locationBinding(isStation: false))
            field("乘车站", text: locationBinding(isStation: true))
            timePicker("列车发车时间", value: $plan.trainDeparture)
            WayCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("中途行程（可选）").font(.headline)
                    Text("不添加就直接前往车站。需要吃饭、取行李或游玩时，再点下方加号。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !plan.activities.isEmpty {
                        if plan.plannedStart == nil {
                            Button("填写计划出发时间") { plan.plannedStart = minuteOfDay(Date()) }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        } else {
                            DatePicker("计划出发时间", selection: Binding(
                                get: { minutesDate(plan.day ?? Date(), plan.plannedStart) ?? Date() },
                                set: { plan.plannedStart = minuteOfDay($0) }),
                                displayedComponents: .hourAndMinute)
                                .environment(\.timeZone, chinaZone)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                            Text("当前计划出发：\(clockText(plan.plannedStart))（24小时制）")
                                .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Text("下面每一站都会从这个时间往后顺序安排；最晚出发只用来核对是否来得及。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, _ in
                        Divider()
                        HStack {
                            Text("第\(index + 1)站").font(.headline)
                            Spacer()
                            Button("移除") { removeStop(at: index) }
                                .frame(minHeight: 44)
                                .accessibilityLabel("移除第\(index + 1)站")
                        }
                        TextField("要做什么，例如吃午饭", text: activityText(index, \.title))
                            .accessibilityLabel("第\(index + 1)站做什么")
                        TextField("中途地点，例如餐厅", text: activityPlace(index))
                            .accessibilityLabel("第\(index + 1)站地点")
                        HStack {
                            TextField("停留时间", text: activityMinutes(index, \.duration)).keyboardType(.numberPad)
                            Text("分钟").foregroundStyle(.secondary)
                        }
                        Toggle("已在这里，无需交通", isOn: activitySamePlace(index))
                        if !plan.activities[index].samePlace {
                            HStack {
                                TextField("从上一处到这里预计用时", text: activityMinutes(index, \.incomingMinutes)).keyboardType(.numberPad)
                                Text("分钟").foregroundStyle(.secondary)
                            }
                        }
                    }
                    if plan.activities.count < 30 {
                        Button { addStop() } label: {
                            Label("添加中途行程", systemImage: "plus.circle.fill")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .accessibilityHint("添加后才需要填写中途地点与时间")
                    } else {
                        Text("每份计划最多添加30个活动。").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.activities.isEmpty ? "去车站预计用时" : "从最后一站去车站预计用时").font(.headline)
                    HStack {
                        TextField("例如 45", text: $travelMinutes).keyboardType(.numberPad)
                        Text("分钟").foregroundStyle(.secondary)
                    }
                    Text(plan.activities.isEmpty ? "只填从出发地点到车站的一段路程，按自己的估计填写。" : "填写最后一站到车站的用时；中途每段路程在上方分别填写。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            WayCard {
                Text("提前到站").font(.footnote).foregroundStyle(.secondary)
                Picker("提前到站", selection: Binding(get: { plan.arrivalLeadMinutes ?? 60 }, set: { plan.arrivalLeadMinutes = $0 })) {
                    Text("30分钟").tag(30)
                    Text("45分钟").tag(45)
                    Text("60分钟").tag(60)
                    Text("90分钟").tag(90)
                }.pickerStyle(.menu)
            }
            let preview = Calculation.run(previewPlan)
            WayCard(tint: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("时间预览").font(.headline)
                    Text("火车发车  \(clockText(plan.trainDeparture))").monospacedDigit()
                    Text("建议到站  \(clockText(plan.effectiveTargetArrival))").monospacedDigit()
                    if plan.activities.isEmpty {
                        Text("建议最晚出发  \(clockText(preview.latestStart))").font(.headline).monospacedDigit()
                    } else {
                        Text("计划出发  \(clockText(plan.plannedStart))").font(.headline).monospacedDigit()
                        Text("预计到站（含\(plan.buffer)分钟缓冲）  \(clockText(preview.buffered))").monospacedDigit()
                        Text(preview.margin.map { $0 >= 0 ? "比建议到站早\($0)分钟" : "比建议到站晚\(-$0)分钟" } ?? "中途时间待补全，暂不能判断是否来得及。")
                        Text("最晚出发参考  \(clockText(preview.latestStart))").monospacedDigit()
                    }
                    ForEach(preview.issues, id: \.self) { Text($0).font(.subheadline).foregroundStyle(.orange) }
                    Text("最晚出发已额外留出\(plan.buffer)分钟路上缓冲；交通时间按你填写的估计计算。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            WayButton(title: "保存草稿", filled: false) { save(continueToTimeline: false) }
            WayButton(title: "保存并查看时间") { save(continueToTimeline: true) }
        }
        .navigationTitle("返程信息").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let editingID, let saved = store.plan(editingID) {
                plan = saved
                plan.simpleJourney = true
                travelMinutes = saved.finalTravel.map(String.init) ?? ""
            }
        }
        .alert("有未保存的修改", isPresented: $showDiscard) { Button("放弃", role: .destructive) { dismiss() }; Button("继续编辑", role: .cancel) {} }
    }
    private func templateActivities(_ template: Int) -> [Activity] {
        if template == 1 {
            let checkout = Activity(title: "退房", kind: .checkout, duration: 20)
            let stored = Activity(title: "寄存行李", kind: .storeBag, duration: 10, predecessorIDs: [checkout.id])
            let explore = Activity(title: "游玩", kind: .sightseeing, duration: 60, required: false, allowShorten: true, minDuration: 30)
            let collect = Activity(title: "取行李", kind: .collectBag, duration: 15, predecessorIDs: [stored.id])
            return [checkout, stored, explore, collect]
        }
        return [Activity(title: "午餐", kind: .meal, duration: 60, required: false, allowShorten: true, minDuration: 30), Activity(title: "取行李", kind: .collectBag, duration: 15)]
    }
    private func addStop() {
        guard plan.activities.count < 30 else { return }
        if plan.activities.isEmpty && plan.plannedStart == nil {
            plan.plannedStart = minuteOfDay(Date())
        }
        plan.activities.append(Activity())
        plan.finalTravel = nil
        travelMinutes = ""
    }
    private func locationBinding(isStation: Bool) -> Binding<String> {
        Binding(get: { isStation ? plan.stationPlace : plan.startPlace }, set: { value in
            if isStation {
                guard plan.stationPlace != value else { return }
                plan.stationPlace = value
                plan.finalTravel = nil
                travelMinutes = ""
            } else {
                guard plan.startPlace != value else { return }
                plan.startPlace = value
                if plan.activities.isEmpty {
                    plan.finalTravel = nil
                    travelMinutes = ""
                } else {
                    plan.activities[0].incomingMinutes = nil
                    plan.activities[0].samePlace = false
                }
            }
        })
    }
    private func removeStop(at index: Int) {
        guard plan.activities.indices.contains(index) else { return }
        plan.activities.remove(at: index)
        if plan.activities.indices.contains(index) {
            plan.activities[index].samePlace = false
            plan.activities[index].incomingMinutes = nil
        } else {
            if plan.activities.isEmpty { plan.plannedStart = nil }
            plan.finalTravel = nil
            travelMinutes = ""
        }
    }
    private func activityText(_ index: Int, _ keyPath: WritableKeyPath<Activity, String>) -> Binding<String> {
        Binding(get: { plan.activities.indices.contains(index) ? plan.activities[index][keyPath: keyPath] : "" },
                set: { if plan.activities.indices.contains(index) { plan.activities[index][keyPath: keyPath] = $0 } })
    }
    private func activityPlace(_ index: Int) -> Binding<String> {
        Binding(get: { plan.activities.indices.contains(index) ? plan.activities[index].place : "" }, set: { value in
            guard plan.activities.indices.contains(index), plan.activities[index].place != value else { return }
            plan.activities[index].place = value
            plan.activities[index].incomingMinutes = nil
            plan.activities[index].samePlace = false
            if plan.activities.indices.contains(index + 1) {
                plan.activities[index + 1].incomingMinutes = nil
                plan.activities[index + 1].samePlace = false
            } else { plan.finalTravel = nil; travelMinutes = "" }
        })
    }
    private func activityMinutes(_ index: Int, _ keyPath: WritableKeyPath<Activity, Int?>) -> Binding<String> {
        Binding(get: { plan.activities.indices.contains(index) ? plan.activities[index][keyPath: keyPath].map(String.init) ?? "" : "" },
                set: { if plan.activities.indices.contains(index) { plan.activities[index][keyPath: keyPath] = Int($0) } })
    }
    private func activitySamePlace(_ index: Int) -> Binding<Bool> {
        Binding(get: { plan.activities.indices.contains(index) ? plan.activities[index].samePlace : false }, set: { value in
            guard plan.activities.indices.contains(index) else { return }
            plan.activities[index].samePlace = value
            plan.activities[index].incomingMinutes = nil
        })
    }
    private func field(_ label: String, text: Binding<String>) -> some View {
        WayCard { VStack(alignment: .leading, spacing: 6) { Text(label).font(.footnote).foregroundStyle(.secondary); TextField("请填写", text: text).textInputAutocapitalization(.never) } }
    }
    private func timePicker(_ label: String, value: Binding<Int?>) -> some View {
        WayCard {
            if value.wrappedValue == nil {
                Button("填写\(label)") { value.wrappedValue = minuteOfDay(Date()) }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    DatePicker(label, selection: Binding(get: { minutesDate(plan.day ?? Date(), value.wrappedValue) ?? Date() }, set: { value.wrappedValue = minuteOfDay($0) }), displayedComponents: .hourAndMinute)
                        .environment(\.timeZone, chinaZone)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    Text("已选：\(clockText(value.wrappedValue))（24小时制）")
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }
    private var previewPlan: Plan {
        var copy = plan
        copy.finalTravel = Int(travelMinutes)
        return copy
    }
    private func save(continueToTimeline: Bool) {
        if plan.status == .active {
            issue = "进行中的行程不能在这里改动，请在“进行中”完成或提前结束后再新建计划。"
            return
        }
        plan.title = String(plan.title.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        let input = travelMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty && !(1...360).contains(Int(input) ?? 0) {
            issue = "去车站预计用时请填写1到360分钟。"
            return
        }
        for (index, activity) in plan.activities.enumerated() {
            if activity.title.count > 40 || activity.place.count > 80 {
                issue = "第\(index + 1)站的名称最多40字，地点最多80字。"
                return
            }
            if let duration = activity.duration, !(1...360).contains(duration) {
                issue = "第\(index + 1)站的停留时间请填写1到360分钟。"
                return
            }
            if let incoming = activity.incomingMinutes, !(1...360).contains(incoming) {
                issue = "去第\(index + 1)站的交通时间请填写1到360分钟。"
                return
            }
        }
        plan.finalTravel = Int(input)
        plan.finalSamePlace = false
        plan.simpleJourney = true
        plan.targetArrival = plan.effectiveTargetArrival
        if plan.activities.isEmpty { plan.plannedStart = nil }
        if plan.trainDeparture != nil && plan.effectiveTargetArrival == nil {
            issue = "提前到站时间不能晚于列车发车时间。"
            return
        }
        if editingID != nil { plan.revision += 1 }
        if plan.status != .active {
            let calculated = Calculation.run(plan)
            let missing = PlanCompletion.missingItems(in: plan)
            plan.status = missing.isEmpty && calculated.complete && calculated.issues.isEmpty ? .ready : .draft
        }
        if store.save(plan) {
            issue = nil
            if editingID != nil || !continueToTimeline { dismiss() }
            else { onSaved(plan.id) }
        }
        else { issue = "保存失败，输入仍保留，请重试。" }
    }
}

struct TimelinePage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.colorScheme) private var scheme
    let id: UUID
    let go: (Route) -> Void
    let onActive: () -> Void
    @State private var showStart = false
    @State private var confirmLate = false
    @State private var menu = false
    var body: some View {
        PageScroll {
            if let plan = store.plan(id) { content(plan) }
        }
        .navigationTitle(store.plan(id)?.isSimpleJourney == true ? "返程时间" : "时间编排").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("开始行程", isPresented: $showStart) {
            Button("确认实际开始并进入进行中") { start() }
            Button("取消", role: .cancel) {}
        } message: { Text("目标到站 \(clockText(store.plan(id)?.targetArrival)) · 实际开始将使用当前中国标准时间。") }
        .alert("按当前估时会晚于目标，仍要开始吗？", isPresented: $confirmLate) { Button("仍要开始") { start() }; Button("取消", role: .cancel) {} }
        .confirmationDialog("更多", isPresented: $menu) {
            Button("时间卡预览") { go(.pdf(id)) }
            Button("调整剩余安排") { go(.adjust(id)) }
            Button("取消", role: .cancel) {}
        }
    }
    @ViewBuilder private func content(_ plan: Plan) -> some View {
        let calc = Calculation.run(plan)
        if plan.isSimpleJourney {
            simpleContent(plan, calc: calc)
        } else {
        PageTitle(title: "时间编排", subtitle: "\(plan.displayTitle) · \(dayText(plan.day))\(plan.isDemo ? " · 演示数据" : "")")
        ResultCard(plan: plan, calc: calc)
        CompletionGuide(items: PlanCompletion.missingItems(in: plan)) { item in
            go(completionRoute(for: item, planID: id))
        }
        WayButton(title: "修改基本条件", filled: false) { go(.editBasics(id)) }
        if !calc.issues.isEmpty { ForEach(calc.issues, id: \.self) { IssueBanner(text: $0) } }
        HStack { Label("最晚开始", systemImage: "clock.arrow.circlepath"); Spacer(); Text(clockText(calc.latestStart)).monospacedDigit() }.font(.headline)
        Text("中国标准时间").font(.footnote).foregroundStyle(.secondary)
        ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, activity in
            if index > 0 || !activity.samePlace { TimelineNode(icon: "arrow.up.right", time: activity.incomingMinutes.map { "\($0)分钟" } ?? "待补全", title: "前往\(activity.place)", detail: activity.incomingMinutes == nil ? "交通时间待补全，点这里填写" : activity.sourceNote.isEmpty ? activity.travelMode : activity.sourceNote, action: { go(.activity(id, index)) }) }
            TimelineNode(icon: activity.required ? "suitcase" : "circle.fill", time: calc.stops.indices.contains(index) ? "\(clockText(calc.stops[index].start))–\(clockText(calc.stops[index].end))" : "\(activity.duration.map(String.init) ?? "待补全")分钟", title: activity.title.isEmpty ? activity.kind.label : activity.title, detail: activity.required ? "必须保留" : activity.allowShorten ? "可选 · 可缩短至\(activity.minDuration ?? 1)分钟" : "可选", action: { go(.activity(id, index)) })
            if plan.status != .active && plan.activities.count > 1 {
                HStack(spacing: 12) {
                    Button("上移") { moveActivity(plan, from: index, to: index - 1) }.disabled(index == 0)
                    Button("下移") { moveActivity(plan, from: index, to: index + 1) }.disabled(index == plan.activities.count - 1)
                }.font(.footnote).padding(.leading, 42)
            }
        }
        TimelineNode(icon: "arrow.up.right", time: plan.finalTravel.map { "\($0)分钟" } ?? "待补全", title: "去车站的交通", detail: plan.stationPlace, action: { go(.activity(id, -1)) })
        TimelineNode(icon: "mappin.circle", time: clockText(calc.physical), title: "物理预计到站", detail: "再预留\(plan.buffer)分钟缓冲", action: nil)
        Text("按填写时长估算，不含实时路况。").font(.subheadline).foregroundStyle(.secondary)
        HStack { WayButton(title: "添加活动", filled: false, disabled: plan.activities.count >= 30) { go(.activity(id, plan.activities.count)) }; WayButton(title: "核对行程", filled: false) { go(.check(id)) } }
        if plan.activities.count >= 30 { Text("每份计划最多添加30个活动。") }
        WayButton(title: "开始行程", disabled: !canStart(plan, calc)) {
            if (calc.margin ?? 1) <= 0 { confirmLate = true } else { showStart = true }
        }
        if !canStart(plan, calc) { Text("请先补全资料并解决顺序与预约问题；仅今天完整计划可开始。").font(.subheadline).foregroundStyle(.secondary) }
        WayButton(title: "更多", filled: false) { menu = true }
        }
    }
    @ViewBuilder private func simpleContent(_ plan: Plan, calc: Calculation) -> some View {
        PageTitle(title: "返程时间", subtitle: "\(plan.displayTitle) · \(dayText(plan.day))")
        if plan.trainDeparture != nil {
        WayCard(tint: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("火车发车").font(.body).foregroundStyle(.secondary)
                ValueText(value: clockText(plan.trainDeparture), emphasized: true)
                Divider()
                HStack { Text("建议到站"); Spacer(); Text(clockText(plan.effectiveTargetArrival)).monospacedDigit() }
                if plan.activities.isEmpty {
                    HStack { Text("建议最晚出发"); Spacer(); Text(clockText(calc.latestStart)).font(.headline).monospacedDigit() }
                    Text("从\(plan.startPlace)到\(plan.stationPlace)，交通预计\(plan.finalTravel.map(String.init) ?? "待补全")分钟，另留\(plan.buffer)分钟路上缓冲。")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    HStack { Text("计划出发"); Spacer(); Text(clockText(plan.plannedStart)).font(.headline).monospacedDigit() }
                    HStack { Text("预计到站（含\(plan.buffer)分钟缓冲）"); Spacer(); Text(clockText(calc.buffered)).font(.headline).monospacedDigit() }
                    Text(calc.margin.map { $0 >= 0 ? "比建议到站早\($0)分钟" : "比建议到站晚\(-$0)分钟" } ?? "中途时间待补全，暂不能判断是否来得及。")
                        .font(.headline)
                    Text("最晚出发参考 \(clockText(calc.latestStart)) · 行程按计划出发时间向后安排")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        } else {
            WayCard(tint: true) { Text("先填返程信息，时间会自动显示在这里。") }
        }
        let missing = PlanCompletion.missingItems(in: plan)
        if let first = missing.first {
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还差\(missing.count)项").font(.headline)
                    Text(first.detail).font(.body).foregroundStyle(.secondary)
                    WayButton(title: "填写\(first.title)", filled: false) { go(.editBasics(id)) }
                }
            }
        }
        if missing.isEmpty { ForEach(calc.issues, id: \.self) { IssueBanner(text: $0) } }
        if !plan.activities.isEmpty {
            Text("中途行程").font(.title3.bold()).padding(.top, 8)
            TimelineNode(icon: "circle.fill", time: clockText(plan.plannedStart), title: "从\(plan.startPlace)出发", detail: "按你选择的计划出发时间顺序安排", action: { go(.editBasics(id)) })
            ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, activity in
                let previousEnd: Int? = index == 0 ? plan.plannedStart : (calc.stops.indices.contains(index - 1) ? calc.stops[index - 1].end : nil)
                let stopStart: Int? = calc.stops.indices.contains(index) ? calc.stops[index].start : nil
                if !activity.samePlace {
                    TimelineNode(icon: "arrow.up.right", time: previousEnd != nil && stopStart != nil ? "\(clockText(previousEnd))–\(clockText(stopStart))" : "待补全",
                                 title: "前往\(activity.place.isEmpty ? "中途地点" : activity.place)",
                                 detail: "预计\(activity.incomingMinutes.map(String.init) ?? "待补全")分钟", action: { go(.editBasics(id)) })
                }
                TimelineNode(icon: "mappin.and.ellipse",
                             time: calc.stops.indices.contains(index) ? "\(clockText(calc.stops[index].start))–\(clockText(calc.stops[index].end))" : "待补全",
                             title: activity.title.isEmpty ? "第\(index + 1)站待填写" : activity.title,
                             detail: "\(activity.place.isEmpty ? "地点待填写" : activity.place) · 停留\(activity.duration.map(String.init) ?? "待补全")分钟",
                             action: { go(.editBasics(id)) })
            }
            TimelineNode(icon: "arrow.up.right", time: calc.stops.last != nil && calc.physical != nil ? "\(clockText(calc.stops.last?.end))–\(clockText(calc.physical))" : "待补全",
                         title: "前往\(plan.stationPlace)", detail: "预计\(plan.finalTravel.map(String.init) ?? "待补全")分钟", action: { go(.editBasics(id)) })
            TimelineNode(icon: "tram.fill", time: clockText(calc.physical), title: "预计到站", detail: "含缓冲预计 \(clockText(calc.buffered)) · 建议到站 \(clockText(plan.effectiveTargetArrival))", action: nil)
        }
        WayButton(title: "修改返程信息", filled: false) { go(.editBasics(id)) }
        if !plan.isDemo { WayButton(title: "是否需要提醒", filled: false) { go(.reminder(id)) } }
        if !plan.startPlace.isEmpty && !plan.stationPlace.isEmpty {
            WayButton(title: "查看真实路线图", filled: false) { go(.routeMap(id)) }
        }
        if !plan.isDemo {
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("锁屏与桌面显示", systemImage: "rectangle.on.rectangle")
                        .font(.headline)
                    Text(widgetStatus(for: plan, missing: missing))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("首次使用要在 iPhone 锁屏长按 → 自定义 → 添加小组件 → 搜索“途鹿旅游”；主屏幕长按空白处 → 编辑 → 添加小组件。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let issue = store.widgetIssue { Text(issue).foregroundStyle(.orange) }
                }
            }
        }
        if let day = plan.day, chinaCalendar.isDate(day, inSameDayAs: Date()) {
            WayButton(title: plan.activities.isEmpty ? "开始前往车站" : "开始中途行程", disabled: !canStart(plan, calc)) {
                let current = Calculation.run(plan, start: minuteOfDay(Date()))
                if (current.margin ?? 0) < 0 { confirmLate = true } else { showStart = true }
            }
        }
        Text("按你填写的交通时长估算，不含实时路况；请以车票和车站通知为准。")
            .font(.subheadline).foregroundStyle(.secondary)
    }
    private func widgetStatus(for plan: Plan, missing: [CompletionItem]) -> String {
        if store.widgetIssue != nil { return "计划已保存在本机，但小组件暂未取得共享数据。" }
        if !missing.isEmpty { return "这份计划还差\(missing.count)项信息，补齐后才会同步到小组件。" }
        if plan.status == .draft { return "这份计划的时间安排还需调整，暂不能显示在小组件。" }
        if let day = plan.day, let departure = plan.trainDeparture,
           let trainDate = minutesDate(day, departure), trainDate <= Date() {
            return "这趟列车的发车时间已过，小组件不会继续显示它。"
        }
        if WidgetPlanSnapshot.preferred(from: store.plans)?.planID == plan.id {
            return "这份计划已准备好供小组件显示。保存计划不会自动把小组件放到屏幕上。"
        }
        return "小组件会优先显示最近出发的有效计划；完成或归档的计划不显示。"
    }
    private func moveActivity(_ original: Plan, from: Int, to: Int) {
        guard original.activities.indices.contains(from), original.activities.indices.contains(to) else { return }
        var p = original
        let moved = p.activities.remove(at: from); p.activities.insert(moved, at: to)
        for index in max(0, min(from, to))...min(p.activities.count - 1, max(from, to) + 1) { p.activities[index].incomingMinutes = nil; p.activities[index].samePlace = false }
        p.revision += 1; p.status = .draft; _ = store.save(p)
    }
    private func canStart(_ p: Plan, _ c: Calculation) -> Bool {
        guard !p.isDemo, store.active == nil, PlanCompletion.missingItems(in: p).isEmpty,
              let day = p.day, chinaCalendar.isDate(day, inSameDayAs: Date()), c.complete else { return false }
        return !c.issues.contains(where: { $0.contains("预约") || $0.contains("最晚") || $0.contains("首版") })
    }
    private func start() {
        guard var p = store.plan(id), canStart(p, Calculation.run(p)) else { return }
        if p.isSimpleJourney { p.plannedStart = minuteOfDay(Date()); p.targetArrival = p.effectiveTargetArrival }
        p.status = .active
        var execution = Execution(startedAt: Date())
        if p.isSimpleJourney && p.activities.isEmpty {
            execution.phase = .finalTravel
            execution.phaseStartedAt = Date()
            execution.expectedEnd = Date().addingTimeInterval(TimeInterval((p.finalTravel ?? 0) * 60))
        }
        p.execution = execution
        if store.save(p) { onActive() }
    }
}
struct ResultCard: View {
    let plan: Plan
    let calc: Calculation
    var body: some View {
        WayCard(tint: true) {
            VStack(alignment: .leading, spacing: 14) {
                Text("到站时间核对").font(.headline)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) { metric("目标到站", clockText(plan.targetArrival)); Divider(); metric("预计到站（含\(plan.buffer)分钟缓冲）", clockText(calc.buffered)) }
                    VStack(alignment: .leading, spacing: 12) { metric("目标到站", clockText(plan.targetArrival)); metric("预计到站（含\(plan.buffer)分钟缓冲）", clockText(calc.buffered)) }
                }
                Text(calc.margin.map { $0 > 0 ? "估时余量\($0)分钟" : $0 == 0 ? "恰好到目标，额外余量为0。" : "比目标晚\(-$0)分钟" } ?? "待补全，暂不能计算完整行程。").font(.headline)
                if let physical = calc.physical { Text("物理预计到站 \(clockText(physical)) · 额外缓冲\(plan.buffer)分钟").font(.subheadline).foregroundStyle(.secondary) }
            }
        }.accessibilityElement(children: .combine)
    }
    private func metric(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 6) { Text(label).font(.footnote).foregroundStyle(.secondary); ValueText(value: value) } }
}
struct IssueBanner: View {
    let text: String
    var body: some View { WayCard { Label(text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
}
struct TimelineNode: View {
    @Environment(\.colorScheme) private var scheme
    let icon: String
    let time: String
    let title: String
    let detail: String
    let action: (() -> Void)?
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.headline).foregroundStyle(Wayfinding.teal(scheme == .dark)).frame(width: 28, height: 28).background(Wayfinding.wash(scheme == .dark), in: Circle())
            VStack(alignment: .leading, spacing: 5) { Text(time).font(.body.monospacedDigit()).foregroundStyle(Wayfinding.teal(scheme == .dark)); Text(title).font(.title3.bold()); Text(detail).font(.body).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            if let action { Button(action: action) { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("编辑\(title)") }
        }.padding(.vertical, 7).accessibilityElement(children: .combine)
    }
}

struct ActivityPage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let index: Int
    @State private var item = Activity()
    @State private var minutes = ""
    @State private var travel = ""
    @State private var minDuration = ""
    @State private var finalOnly = false
    @State private var fixedEnabled = false
    @State private var latestEnabled = false
    @State private var fixedTime = Date()
    @State private var latestTime = Date()
    @State private var issue: String? = nil
    @State private var loaded = false
    var body: some View {
        PageScroll {
            PageTitle(title: finalOnly ? "去车站的交通" : "活动与路段")
            if let issue { IssueBanner(text: issue) }
            if let plan = store.plan(id) {
                let items = PlanCompletion.missingItems(in: plan).filter {
                    $0.destination == (index == -1 ? .finalTravel : .activity(index))
                }
                if !items.isEmpty {
                    WayCard(tint: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("这一步需要填写").font(.headline)
                            ForEach(items) { Text("• \($0.title)：\($0.detail)").font(.body) }
                        }
                    }
                }
            }
            if !finalOnly {
                WayCard { Picker("活动类型", selection: $item.kind) { ForEach(ActivityKind.allCases) { Text($0.label).tag($0) } } }
                textField("活动名称", text: $item.title)
                textField("地点", text: $item.place)
                numberField("停留时长（1–360分钟）", text: $minutes)
                WayCard { Toggle("必须保留", isOn: $item.required) }
                if !item.required { WayCard { Toggle("允许缩短", isOn: $item.allowShorten) }; if item.allowShorten { numberField("最短停留", text: $minDuration) } }
                if item.kind == .collectBag { WayCard { Text("取行李等必须任务受保护，调整时不会自动移除。") } }
                WayCard { Toggle("固定开始时间", isOn: $fixedEnabled) }
                if fixedEnabled { WayCard { DatePicker("固定开始", selection: $fixedTime, displayedComponents: .hourAndMinute) } }
                WayCard { Toggle("最晚完成时间", isOn: $latestEnabled) }
                if latestEnabled { WayCard { DatePicker("最晚完成", selection: $latestTime, displayedComponents: .hourAndMinute) } }
                if fixedEnabled && latestEnabled { IssueBanner(text: "固定开始与最晚完成不能同时设置。") }
                if let p = store.plan(id), index > 0 { WayCard { Picker("需要先完成", selection: Binding(get: { item.predecessorIDs.first }, set: { item.predecessorIDs = $0.map { [$0] } ?? [] })) { Text("无").tag(UUID?.none); ForEach(p.activities.prefix(index)) { previous in Text(previous.title).tag(Optional(previous.id)) } } } }
            }
            WayCard { Toggle(finalOnly ? "车站与上一地点相同" : "已在这里，无需交通", isOn: $item.samePlace) }
            if !item.samePlace { numberField("交通预计用时（1–360分钟）", text: $travel); WayCard { Picker("交通方式", selection: $item.travelMode) { ForEach(["步行", "公交或地铁", "出租车", "其他"], id: \.self) { Text($0) } } } }
            if !finalOnly { textField("估时依据（选填）", text: $item.sourceNote) }
            Text("交通估时由你输入；空值不会当作0。").font(.subheadline).foregroundStyle(.secondary)
            WayButton(title: "保存") { save() }
            if index >= 0, index < (store.plan(id)?.activities.count ?? 0) { Button("删除活动", role: .destructive) { delete() }.frame(maxWidth: .infinity, minHeight: 44) }
        }
        .navigationTitle(finalOnly ? "最终交通" : "活动与路段").navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }
    private func textField(_ title: String, text: Binding<String>) -> some View { WayCard { VStack(alignment: .leading) { Text(title).font(.footnote).foregroundStyle(.secondary); TextField(title, text: text) } } }
    private func numberField(_ title: String, text: Binding<String>) -> some View { WayCard { VStack(alignment: .leading) { Text(title).font(.footnote).foregroundStyle(.secondary); TextField(title, text: text).keyboardType(.numberPad) } } }
    private func load() {
        guard !loaded, let p = store.plan(id) else { return }; loaded = true
        finalOnly = index == -1
        if finalOnly { travel = p.finalTravel.map(String.init) ?? ""; item.samePlace = p.finalSamePlace }
        else if p.activities.indices.contains(index) { item = p.activities[index]; minutes = item.duration.map(String.init) ?? ""; travel = item.incomingMinutes.map(String.init) ?? ""; minDuration = item.minDuration.map(String.init) ?? ""; fixedEnabled = item.fixedStart != nil; latestEnabled = item.latestFinish != nil; fixedTime = minutesDate(p.day ?? Date(), item.fixedStart) ?? Date(); latestTime = minutesDate(p.day ?? Date(), item.latestFinish) ?? Date() }
    }
    private func save() {
        guard var p = store.plan(id) else { return }
        if p.status == .active, let ex = p.execution, index >= 0, index <= ex.index { issue = "正在前往此活动，先记录抵达。"; return }
        if finalOnly {
            guard item.samePlace || ((Int(travel).map { (1...360).contains($0) }) ?? false) else { issue = "请先补全交通时间，不会把空值当成0。"; return }
            p.finalSamePlace = item.samePlace; p.finalTravel = item.samePlace ? 0 : Int(travel)
        } else {
            guard !(fixedEnabled && latestEnabled) else { issue = "固定开始与最晚完成不能同时设置。"; return }
            guard !item.title.isEmpty, !item.place.isEmpty, let d = Int(minutes), (1...360).contains(d) else { issue = "时长需为1–360分钟，最短停留不能超过原时长。"; return }
            if !item.samePlace, let t = Int(travel), !(1...360).contains(t) { issue = "交通时间须为1–360分钟。"; return }
            if item.allowShorten, let m = Int(minDuration), !(1...d).contains(m) { issue = "时长需为1–360分钟，最短停留不能超过原时长。"; return }
            item.fixedStart = fixedEnabled ? minuteOfDay(fixedTime) : nil; item.latestFinish = latestEnabled ? minuteOfDay(latestTime) : nil
            item.duration = d; item.incomingMinutes = item.samePlace ? 0 : Int(travel); item.minDuration = item.allowShorten ? Int(minDuration) : nil
            if fixedEnabled || latestEnabled { item.allowShorten = false }
            if item.kind == .collectBag || item.kind == .storeBag || item.kind == .checkout { item.required = true; item.allowShorten = false }
            if p.activities.indices.contains(index) { p.activities[index] = item } else { p.activities.append(item) }
        }
        p.revision += 1
        if p.status != .active {
            p.status = PlanCompletion.missingItems(in: p).isEmpty && Calculation.run(p).complete ? .ready : .draft
        }
        if store.save(p) { dismiss() } else { issue = "保存失败，输入仍保留，请重试。" }
    }
    private func delete() {
        guard var p = store.plan(id), p.activities.indices.contains(index), !p.activities[index].required, p.status != .active else { issue = "此活动被后续任务依赖，请先调整关联。"; return }
        p.activities.remove(at: index)
        if p.activities.indices.contains(index) { p.activities[index].incomingMinutes = nil; p.activities[index].samePlace = false }
        else { p.finalTravel = nil; p.finalSamePlace = false }
        p.revision += 1; p.status = .draft
        if store.save(p) { dismiss() }
    }
}

struct CheckPage: View {
    @EnvironmentObject private var store: PlanStore
    let id: UUID
    let go: (Route) -> Void
    var body: some View {
        PageScroll {
            if let plan = store.plan(id) {
                let calc = Calculation.run(plan)
                PageTitle(title: "核对行程", subtitle: plan.displayTitle)
                Text("信息缺口").font(.title3.bold())
                CompletionGuide(items: PlanCompletion.missingItems(in: plan)) { item in
                    go(completionRoute(for: item, planID: id))
                }
                if !calc.complete { IssueBanner(text: "请先补全交通时间，不会把空值当成0。") }
                else { WayCard { Text("未发现规则冲突，实际用时仍需自行确认。") } }
                Text("顺序与预约").font(.title3.bold())
                ForEach(calc.issues.filter { $0.contains("预约") || $0.contains("最晚") }, id: \.self) { IssueBanner(text: $0) }
                if calc.issues.isEmpty { WayCard { Text("未发现规则冲突，实际用时仍需自行确认。") } }
                Text("到站时间").font(.title3.bold())
                ResultCard(plan: plan, calc: calc)
                WayCard { VStack(alignment: .leading, spacing: 5) { Text("最晚开始 \(clockText(calc.latestStart))"); Text("按填写时长估算，不含实时路况。") } }
                WayButton(title: "调整剩余安排", filled: false, disabled: !calc.complete) { go(.adjust(id)) }
            }
        }.navigationTitle("核对行程").navigationBarTitleDisplayMode(.inline)
    }
}

struct AdjustPage: View {
    @EnvironmentObject private var store: PlanStore
    let id: UUID
    let go: (Route) -> Void
    @State private var selectedMinutes: Int? = nil
    var body: some View {
        PageScroll {
            if let plan = store.plan(id) {
                let calc = Calculation.run(plan)
                PageTitle(title: "调整剩余安排", subtitle: plan.displayTitle)
                ResultCard(plan: plan, calc: calc)
                Text("缩短可选活动").font(.title3.bold())
                let choices = plan.activities.enumerated().filter { $0.element.allowShorten && !$0.element.required && $0.element.fixedStart == nil && $0.element.latestFinish == nil && (plan.execution?.phase != .activity || $0.offset != plan.execution?.index) }
                if choices.isEmpty { IssueBanner(text: "没有可自动缩短的活动，请检查你的时间安排。") }
                ForEach(choices, id: \.element.id) { _, activity in
                    WayCard { VStack(alignment: .leading, spacing: 10) { Text(activity.title).font(.headline); Text("当前\(activity.duration ?? 0)分钟 · 可缩短至\(activity.minDuration ?? 1)分钟"); Picker("调整后时长", selection: Binding(get: { selectedMinutes ?? activity.duration ?? 1 }, set: { selectedMinutes = $0 })) { ForEach((activity.minDuration ?? 1)...(activity.duration ?? 1), id: \.self) { Text("\($0)分钟").tag($0) } }.pickerStyle(.menu) } }
                }
                WayCard(tint: true) { VStack(alignment: .leading, spacing: 5) { Text("必须任务保持不变").font(.headline); Text("取行李及已开始的活动不会自动缩短或移除。") } }
                WayButton(title: "查看调整前后", disabled: choices.isEmpty || selectedMinutes == nil || selectedMinutes == choices.first?.element.duration) { go(.compare(id, selectedMinutes ?? 0)) }
            }
        }.navigationTitle("调整剩余安排").navigationBarTitleDisplayMode(.inline)
    }
}

struct ComparePage: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let minutes: Int
    let applied: () -> Void
    @State private var confirmLate = false
    @State private var issue: String? = nil
    @State private var baselineRevision: Int? = nil
    @State private var baselineEventAt: Date? = nil
    var body: some View {
        PageScroll {
            if let original = store.plan(id) {
                let changed = revised(original)
                PageTitle(title: "调整前后", subtitle: original.displayTitle)
                if let issue { IssueBanner(text: issue) }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { compareCard("原安排", original); compareCard("调整后", changed) }
                    VStack(spacing: 12) { compareCard("原安排", original); compareCard("调整后", changed) }
                }
                Text("变更明细").font(.title3.bold())
                WayCard { HStack { Text("\(original.activities.first?.title ?? "活动")"); Spacer(); Text("\(original.activities.first?.duration ?? 0) → \(minutes) 分钟") } }
                WayCard { Text("必须任务“取行李”仍保留；交通估时与目标到站保持不变。") }
                if let margin = Calculation.run(changed).margin, margin < 0 { IssueBanner(text: "调整后仍晚\(-margin)分钟") }
                HStack { WayButton(title: "返回修改", filled: false) { dismiss() }; WayButton(title: "确认应用", disabled: changed.activities.first?.duration == original.activities.first?.duration) { if (Calculation.run(changed).margin ?? 0) < 0 { confirmLate = true } else { apply() } } }
            }
        }
        .navigationTitle("调整前后").navigationBarTitleDisplayMode(.inline)
        .onAppear { baselineRevision = store.plan(id)?.revision; baselineEventAt = store.plan(id)?.execution?.lastEventAt }
        .alert("仍晚于目标，保留此安排？", isPresented: $confirmLate) { Button("保留此安排") { apply() }; Button("取消", role: .cancel) {} }
    }
    private func revised(_ p: Plan) -> Plan { var copy = p; if let i = copy.activities.indices.first(where: { index in let a = copy.activities[index]; return a.allowShorten && !a.required && (p.execution == nil || index > (p.execution?.index ?? -1) || p.execution?.phase == .between) }) { copy.activities[i].duration = minutes }; return copy }
    private func compareCard(_ label: String, _ p: Plan) -> some View { let c = Calculation.run(p); return WayCard(tint: label == "调整后") { VStack(alignment: .leading, spacing: 10) { Text(label).font(.headline); ValueText(value: clockText(c.buffered)); Text("预计到站（含\(p.buffer)分钟缓冲）").font(.footnote); Text(c.margin.map { $0 == 0 ? "额外余量0" : $0 > 0 ? "余量\($0)分钟" : "晚\(-$0)分钟" } ?? "待补全") } } }
    private func apply() {
        guard let p = store.plan(id), p.revision == baselineRevision, p.execution?.lastEventAt == baselineEventAt else { issue = "行程已发生变化，请重新计算后预览。"; return }
        var next = revised(p); next.revision += 1; next.changeNotes.append("\(p.activities.first?.title ?? "活动") \(p.activities.first?.duration ?? 0)→\(minutes)分钟")
        if store.save(next) { applied() } else { issue = "保存失败，输入仍保留，请重试。" }
    }
}

struct RecordDetailPage: View {
    @EnvironmentObject private var store: PlanStore
    let id: UUID
    let go: (Route) -> Void
    var body: some View {
        PageScroll {
            if let plan = store.plan(id) {
                PageTitle(title: "记录详情", subtitle: "\(plan.displayTitle) · \(dayText(plan.day))")
                StatusBadge(title: plan.status.label, warning: plan.status == .ended)
                WayCard(tint: true) { VStack(alignment: .leading, spacing: 12) { Text("计划时间／实际时间").font(.headline); Text("目标到站 \(clockText(plan.targetArrival))"); Text(plan.actualArrival.map { "实际到站 \(timeText($0))" } ?? "未记录实际到站时间"); if let actual = minuteOfDay(plan.actualArrival), let target = plan.targetArrival { Text(actual <= target ? "实际比目标早\(target - actual)分钟" : "实际比目标晚\(actual - target)分钟") } } }
                if plan.status == .ended { IssueBanner(text: "未完成事项 · 行程已提前结束") }
                Text("变更记录").font(.title3.bold())
                if plan.changeNotes.isEmpty { WayCard { Text("暂无调整记录") } }
                ForEach(plan.changeNotes, id: \.self) { note in WayCard { Text(note) } }
                WayButton(title: "时间卡预览", filled: false) { go(.pdf(id)) }
                Text("历史记录不会随新计划变化").font(.subheadline).foregroundStyle(.secondary)
            }
        }.navigationTitle("记录详情").navigationBarTitleDisplayMode(.inline)
    }
}
struct TemplatesPage: View {
    @EnvironmentObject private var store: PlanStore
    let go: (Route) -> Void
    var body: some View {
        PageScroll {
            PageTitle(title: "从模板开始", subtitle: "使用前请核对日期、地点和全部时长。")
            Button { go(.create) } label: { templateCard("空白计划", "从基本条件开始填写。", "square.and.pencil") }.buttonStyle(.plain)
            Button { go(.createTemplate(1)) } label: { templateCard("退房后再逛一处", "退房 → 寄存行李 → 可选游玩 → 取行李 → 车站", "suitcase.rolling") }.buttonStyle(.plain)
            Button { go(.createTemplate(2)) } label: { templateCard("午餐后直接返程", "可选午餐 → 取行李 → 车站；使用前行李已寄存。", "fork.knife") }.buttonStyle(.plain)
            Button { go(.timeline(Plan.demoID)) } label: { templateCard("体验虚构示例", "演示数据，不是真实路线；不安排提醒。", "play.rectangle") }.buttonStyle(.plain)
        }.navigationTitle("模板与示例").navigationBarTitleDisplayMode(.inline)
    }
    private func templateCard(_ title: String, _ detail: String, _ icon: String) -> some View { WayCard { HStack(alignment: .top, spacing: 12) { Image(systemName: icon).font(.title2); VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(detail).font(.body).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") } } }
}
struct PDFPage: View {
    @EnvironmentObject private var store: PlanStore
    let id: UUID
    @State private var detailed = false
    @State private var addresses = false
    @State private var notes = false
    @State private var exportURL: URL? = nil
    @State private var issue: String? = nil
    var body: some View {
        PageScroll {
            if let plan = store.plan(id) {
                PageTitle(title: "时间卡预览", subtitle: "这是静态副本，不会随行程更新。分享前请核对个人信息。")
                Picker("样式", selection: $detailed) { Text("摘要").tag(false); Text("详细").tag(true) }.pickerStyle(.segmented)
                if detailed { WayCard { VStack { Toggle("包含详细地址", isOn: $addresses); Toggle("包含备注", isOn: $notes) } } }
                if let issue { IssueBanner(text: issue) }
                WayCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("途鹿旅游").font(.headline)
                        Text(plan.displayTitle).font(.system(.title, design: .rounded, weight: .bold))
                        Text("\(dayText(plan.day)) · \(plan.city) · \(plan.status.label)")
                        Divider()
                        Text("目标到站 \(clockText(plan.targetArrival))")
                        Text("预计到站（含\(plan.buffer)分钟缓冲） \(clockText(Calculation.run(plan).buffered))")
                        ForEach(plan.activities) { item in Text("• \(item.title) · \(item.duration.map(String.init) ?? "待补全")分钟") }
                        if detailed { Text("物理预计到站 \(clockText(Calculation.run(plan).physical))"); Text("去车站交通 \(plan.finalTravel.map(String.init) ?? "待补全")分钟") }
                        if notes && !plan.notes.isEmpty { Text(plan.notes) }
                        Text("按填写时长估算，不含实时路况。").font(.subheadline)
                        Text("静态副本 · revision \(plan.revision)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                WayButton(title: "生成PDF") {
                    do { exportURL = try PDFExport.make(plan: plan, detailed: detailed, addresses: addresses, notes: notes); issue = nil }
                    catch { issue = "导出失败，原计划未改变。" }
                }
                if let exportURL { ShareLink(item: exportURL, preview: SharePreview(plan.displayTitle)) { Text("导出PDF").font(.headline).frame(maxWidth: .infinity, minHeight: 48) } }
            }
        }.navigationTitle("时间卡预览").navigationBarTitleDisplayMode(.inline)
    }
}
struct SettingsPage: View {
    @EnvironmentObject private var store: PlanStore
    @EnvironmentObject private var wishes: WishStore
    @ObservedObject private var reminders = ReminderCenter.shared
    @State private var deleteAll = false
    let go: (Route) -> Void
    var body: some View {
        PageScroll {
            WayCard { Label("外观 · 黑灰色调", systemImage: "moon.stars") }
            WayCard { Text("语言 · 中文") }
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("锁屏与主屏幕小组件").font(.headline)
                    Text("锁屏长按 → 自定义 → 添加小组件；主屏幕长按空白处 → 编辑 → 添加小组件。搜索“途鹿旅游”并添加。小组件显示最近一份资料完整、尚未发车的计划。")
                        .font(.body)
                    if let issue = store.widgetIssue { IssueBanner(text: issue) }
                }
            }
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("行程提醒").font(.headline)
                    Text("通知权限：\(reminders.permission)")
                    Text(reminders.enabledPlanID.flatMap { id in store.plan(id)?.displayTitle }.map { "当前提醒：\($0)" } ?? "提醒未开启，仍可使用全部规划功能。")
                    Text("从下方选择一份计划，单独设置是否需要提醒。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(store.plans.filter { ![.finished, .ended, .archived].contains($0.status) }) { plan in
                        Button("设置 · \(plan.displayTitle)") { go(.reminder(plan.id)) }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            WayCard { VStack(alignment: .leading, spacing: 8) { Text("本地存储").font(.headline); Text("数据保存在本机，首版不提供云同步。"); Text("PDF仅供阅读，不能恢复App内计划。"); Text("系统备份取决于设备设置，卸载或设备损坏可能导致数据丢失。") } }
            WayButton(title: "查看示例", filled: false) { go(.templates) }
            WayButton(title: "帮助与关于途鹿旅游", filled: false) { go(.help) }
            Button("删除全部数据", role: .destructive) { deleteAll = true }.frame(maxWidth: .infinity, minHeight: 44).disabled(store.plans.isEmpty && wishes.wishes.isEmpty)
        }.navigationTitle("设置与数据").navigationBarTitleDisplayMode(.inline)
        .task { await reminders.refreshPermission() }
        .alert("将删除本机全部计划、记录和心愿，已分享的文件不会删除。", isPresented: $deleteAll) { Button("确认删除全部", role: .destructive) { if store.removeAll() { wishes.removeAll() } }; Button("取消", role: .cancel) {} }
    }
}
struct HelpPage: View {
    var body: some View {
        PageScroll {
            PageTitle(title: "帮助与关于")
            WayCard { VStack(alignment: .leading, spacing: 8) { Text("如何计算时间").font(.headline); Text("余量来自你填写的时长，不代表保证准时到达。"); Text("目标到站、物理预计、额外缓冲和含缓冲预计分别计算。缺少路段时间时完整结果待补全。") } }
            WayCard { VStack(alignment: .leading, spacing: 8) { Text("隐私与数据").font(.headline); Text("计划和心愿保存在本机；删除本机数据不会删除已分享的文件。PDF只供阅读，不能恢复App内计划。") } }
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于途鹿旅游").font(.headline)
                    Text("途鹿旅游帮你把返程时间和路线理清楚。填写出发地、车站与发车时间，可按自己的安排加入中途站点；计划保存后可查看路线、单独开启提醒，并通过小组件查看关键时间。")
                    Text("计划和心愿保存在本机。地图路线需要网络，行程时间按你填写的用时估算。")
                    Text("联系邮箱：lvyouxu@gmail.com。隐私政策和 App 使用协议可在个人中心查看。")
                }
            }
        }.navigationTitle("帮助与关于").navigationBarTitleDisplayMode(.inline)
    }
}
