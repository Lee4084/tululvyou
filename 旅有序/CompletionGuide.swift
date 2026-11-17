import SwiftUI

struct CompletionGuide: View {
    let items: [CompletionItem]
    let onSelect: (CompletionItem) -> Void
    var body: some View {
        if !items.isEmpty {
            WayCard(tint: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("还差\(items.count)项，按顺序补全", systemImage: "list.bullet.circle")
                        .font(.headline)
                    Text(items.allSatisfy { $0.destination == .basics }
                         ? "点“去填写”可返回返程信息页；暂时不知道交通时间，也可以先保存草稿。"
                         : "点“去填写”会直接打开对应位置；暂时不知道交通时间，也可以先保存草稿。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(items) { item in
                        Button { onSelect(item) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.body.weight(.semibold))
                                    Text(item.detail).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Text("去填写").font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.right").font(.footnote)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("填写\(item.title)")
                        if item.id != items.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

func completionRoute(for item: CompletionItem, planID: UUID) -> Route {
    switch item.destination {
    case .basics: .editBasics(planID)
    case .activity(let index): .activity(planID, index)
    case .finalTravel: .activity(planID, -1)
    }
}
