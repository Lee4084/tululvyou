import SwiftUI

struct PersonalCenterPage: View {
    @EnvironmentObject private var plans: PlanStore
    @EnvironmentObject private var wishes: WishStore
    @Environment(\.colorScheme) private var scheme
    @FocusState private var wishFocused: Bool
    @State private var wishText = ""
    let go: (Route) -> Void

    private var unfinished: [Plan] {
        plans.plans.filter { $0.status == .ended }
            .sorted { ($0.day ?? .distantPast) > ($1.day ?? .distantPast) }
    }

    var body: some View {
        PageScroll {
            PageTitle(title: "个人中心", subtitle: "收藏想去的地方，也回看走过的路。")
            Button { go(.myRecords) } label: {
                WayCard(tint: true) {
                    HStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40, design: .rounded))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("我的旅程记录").font(.title3.bold())
                            Text("\(plans.plans.count) 份旅程 · 查看与管理")
                                .font(.body).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.subheadline)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("我的旅程记录")

            Text("心愿墙").font(.title3.bold()).padding(.top, 10)
            WayCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("把下一站，先写在这里。")
                        .font(.body).foregroundStyle(Wayfinding.muted(scheme == .dark))
                    TextField("写下一个想去的地方或心愿", text: $wishText, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($wishFocused)
                        .submitLabel(.done)
                        .onSubmit(addWish)
                        .padding(12)
                        .background(Wayfinding.raised(scheme == .dark), in: RoundedRectangle(cornerRadius: 12))
                    if let message = wishes.message {
                        Text(message).font(.body).foregroundStyle(Wayfinding.amber(scheme == .dark))
                    }
                    WayButton(title: "加入心愿墙", disabled: wishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        addWish()
                    }
                }
            }
            if wishes.wishes.isEmpty {
                WayCard { Text("心愿墙还是空的，写下第一个想去的地方吧。")
                    .font(.body).foregroundStyle(.secondary) }
            } else {
                ForEach(wishes.wishes) { wish in
                    WayCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkle").foregroundStyle(Wayfinding.amber(scheme == .dark))
                            Text(wish.text).font(.body.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { wishes.remove(wish.id) } label: {
                                Image(systemName: "trash").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("删除心愿：\(wish.text)")
                        }
                    }
                }
            }

            Text("未完成的旅程").font(.title3.bold()).padding(.top, 10)
            if unfinished.isEmpty {
                WayCard { Text("还没有提前结束的旅程记录。")
                    .font(.body).foregroundStyle(.secondary) }
            } else {
                ForEach(unfinished) { plan in
                    Button { go(.record(plan.id)) } label: {
                        WayCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(plan.displayTitle).font(.headline)
                                    Text("\(dayText(plan.day)) · 提前结束")
                                        .font(.body).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.subheadline)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }

            Text("设置与服务").font(.title3.bold()).padding(.top, 10)
            menuRow("设置与数据", symbol: "gearshape") { go(.settings) }
            menuRow("隐私政策", symbol: "hand.raised") { go(.privacy) }
            menuRow("App 使用协议", symbol: "doc.text") { go(.agreement) }
            menuRow("帮助与关于", symbol: "questionmark.circle") { go(.help) }
            Text("联系邮箱：lvyouxu@gmail.com")
                .font(.body).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
        }
        .navigationBarHidden(true)
    }

    private func menuRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WayCard {
                HStack(spacing: 12) {
                    Image(systemName: symbol).frame(width: 25)
                    Text(title).font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.subheadline)
                }
                .frame(minHeight: 35)
            }
        }.buttonStyle(.plain)
    }

    private func addWish() {
        if wishes.add(wishText) {
            wishText = ""
            wishFocused = false
        }
    }
}

enum LegalKind: Equatable {
    case privacy, agreement
    var title: String { self == .privacy ? "隐私政策" : "App 使用协议" }
    var onlineURL: URL {
        switch self {
        case .privacy:
            URL(string: "https://docs.google.com/document/d/181JFFTIvkIHggjmweYQEvX2wfG9ZtgeyyM2stXeFNqg/edit?tab=t.0")!
        case .agreement:
            URL(string: "https://docs.google.com/document/d/1MVV9jkBBT3WjM2Th-T13kz0nJBSSB3Psu0-HEK6VtV0/edit?tab=t.0")!
        }
    }
}

struct LegalPage: View {
    let kind: LegalKind
    var body: some View {
        PageScroll {
            PageTitle(title: kind.title, subtitle: "途鹿旅游 · 更新于 2026 年 11 月 17 日")
            WayCard(tint: true) {
                Text("请在使用途鹿旅游前阅读以下内容。如有疑问，可通过文末邮箱联系我们。")
                    .font(.body.weight(.semibold))
            }
            Link(destination: kind.onlineURL) {
                WayCard {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right.square")
                        Text("查看在线版本").font(.body.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.subheadline)
                    }
                    .frame(minHeight: 44)
                }
            }
            .buttonStyle(.plain)
            if kind == .privacy { privacyContent }
            else { agreementContent }
            WayCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("联系我们").font(.headline)
                    Text("如对本政策或协议有疑问，或希望反馈数据处理问题，请发送邮件至：")
                    Text("lvyouxu@gmail.com").font(.body.weight(.semibold))
                    Link("发送邮件", destination: URL(string: "mailto:lvyouxu@gmail.com")!)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
        }
        .navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    @ViewBuilder private var privacyContent: some View {
        section("一、适用范围与运营者", "本政策适用于途鹿旅游 iPhone App（以下简称“本 App”）。途鹿旅游提供返程计划、路线查看、提醒、小组件和本机心愿记录功能。你可以通过文末邮箱联系途鹿旅游运营者。本政策自 App 公开发布之日起生效。")
        section("二、处理的信息与用途", "你主动填写的返程日期、出发地点、车站、发车时间、预计交通用时、活动、备注、执行记录及心愿，用于在本机生成、保存和展示行程。提醒设置用于安排本地通知；符合条件的计划摘要用于锁屏和主屏幕小组件。当前版本不要求注册账号，也不接入广告或统计 SDK。请勿填写使用功能所不需要的身份证号等敏感信息。")
        section("三、系统权限与小组件", "只有你主动开启提醒时，本 App 才申请 iPhone 通知权限。你可以在 App 中关闭提醒，也可以在系统设置中撤回通知权限；拒绝权限不影响计划、地图和心愿功能。小组件在设备屏幕上显示车站及时间，屏幕旁的人可能看到这些信息；你可以随时从锁屏或主屏幕移除小组件。")
        section("四、地图与第三方服务", "打开路线图时，本 App 会把你填写的地点名称用于 Apple 地图地点搜索，并在选择驾车或步行路线时请求 Apple 地图计算路线。只有你点选“在高德查看路线”后，已选起终点的名称与坐标才会通过网页地址发送给高德地图。以上服务需要网络，并受相应服务的隐私规则约束。本 App 当前不申请设备实时定位权限，地图估时也不会替换你手填的交通用时。")
        section("五、PDF 导出与分享", "你可以在本机生成包含计划内容的 PDF。只有你主动调用系统分享功能时，文件才会交给你选择的接收方或 App。生成的临时文件可能由 iOS 在设备上保留一段时间；已经分享的副本需在接收方自行管理，删除 App 内的计划不会自动删除这些副本。")
        section("六、保存期限与保护", "计划、心愿和提醒设置主要保存在你的设备上，直至你在 App 中删除相应内容或卸载 App。小组件使用本机共享容器读取计划摘要。本 App 当前没有自有云端同步服务，也不会把完整计划上传到自有服务器。系统备份可能另行保留副本，其保留和删除受 iPhone 备份设置控制。")
        section("七、你的选择与权利", "你可以在 App 中查看、修改或删除计划，删除单条心愿，并在“设置与数据”中删除本机计划、记录和心愿。你可以关闭提醒或撤回系统通知权限；卸载 App 可停止本机使用。若操作遇到问题，请通过文末邮箱联系。由于我们不提供账号或云同步，无法从服务器直接读取或删除仅保存在你设备上的内容，但会提供处理指引。")
        section("八、未成年人及政策更新", "未成年人应在监护人指导下使用本 App，不要填写与返程规划无关的个人信息。若功能或信息处理方式发生变化，我们会更新本政策并在 App 中展示；依法需要重新取得同意的，会在处理前征求你的同意。")
    }

    @ViewBuilder private var agreementContent: some View {
        section("一、协议范围", "本协议适用于途鹿旅游 iPhone App。途鹿旅游提供返程时间规划、路线查看、本地提醒、小组件和本机心愿记录。使用相关功能前，请阅读本协议及隐私政策。本协议自 App 公开发布之日起生效。")
        section("二、服务边界", "本 App 根据你填写的信息计算建议时间，不提供车票查询或预订、交通运输、实时路况保证或准时到站承诺。地图路线可能由 Apple 地图或你主动打开的高德地图提供；班次、路况、地点搜索结果和系统通知状态可能变化。出发前请核对车票、车站和官方信息。")
        section("三、你的使用责任", "请如实填写与返程规划有关的信息，并自行判断交通用时和预留时间。请勿利用本 App 输入违法内容或侵害他人权益的信息；未成年人应在监护人指导下使用。你的计划、心愿及导出文件由你自行管理和备份。")
        section("四、数据与第三方功能", "计划和心愿主要保存在本机。计划可在 App 内编辑或删除；心愿可删除后重新添加。通知、小组件和系统分享受 iPhone 设置影响；地图服务需要网络并适用相应第三方规则。你主动分享 PDF 后，接收方对副本的处理不受本 App 控制。具体信息处理方式请查看隐私政策。")
        section("五、服务变更与停止使用", "我们可能因功能调整、系统变化或维护更新本 App 和本协议，并在 App 中展示更新内容。你可以随时停止使用并卸载 App；卸载前请自行保存需要保留的计划或导出文件。")
        section("六、争议与联系", "本协议的订立、履行和解释适用中华人民共和国法律。因使用本 App 发生争议，可先通过文末邮箱协商；协商不成的，依法向有管辖权的人民法院提起诉讼。")
    }

    private func section(_ title: String, _ body: String) -> some View {
        WayCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                Text(body).font(.body).lineSpacing(4)
            }
        }
    }
}
