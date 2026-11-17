import SwiftUI
import WidgetKit

private struct JourneyData: Codable {
    let planID: UUID
    let day: Date
    let station: String
    let departure: Int
    let targetArrival: Int
    let latestStart: Int?
    let plannedStart: Int?
    let bufferedArrival: Int?

    private static let zone = TimeZone(identifier: "Asia/Shanghai")!
    private static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = zone
        return value
    }

    var departureDate: Date {
        Self.calendar.startOfDay(for: day).addingTimeInterval(TimeInterval(departure * 60))
    }

    static func current(now: Date = Date()) -> JourneyData? {
        guard let defaults = UserDefaults(suiteName: "group.www.huankecontact.test"),
              let bytes = defaults.data(forKey: "LvYouXu.widget.plan.v1"),
              let value = try? JSONDecoder().decode(JourneyData.self, from: bytes),
              value.departureDate > now else { return nil }
        return value
    }
}

private struct JourneyEntry: TimelineEntry {
    let date: Date
    let journey: JourneyData?
}

private struct JourneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> JourneyEntry { JourneyEntry(date: Date(), journey: nil) }
    func getSnapshot(in context: Context, completion: @escaping (JourneyEntry) -> Void) {
        completion(JourneyEntry(date: Date(), journey: JourneyData.current()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<JourneyEntry>) -> Void) {
        let now = Date()
        let journey = JourneyData.current(now: now)
        let next = min(now.addingTimeInterval(15 * 60), journey?.departureDate ?? now.addingTimeInterval(15 * 60))
        completion(Timeline(entries: [JourneyEntry(date: now, journey: journey)], policy: .after(next)))
    }
}

private struct JourneyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: JourneyEntry

    private func time(_ minute: Int?) -> String {
        guard let minute else { return "待补全" }
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.journey?.station ?? "途鹿旅游 · 暂无行程")
                        .font(.headline).lineLimit(1)
                    if let journey = entry.journey {
                        if let start = journey.plannedStart, let arrival = journey.bufferedArrival {
                            Text("出发 \(time(start)) · 发车 \(time(journey.departure))")
                            Text("含缓冲到站 \(time(arrival))")
                        } else {
                            Text("发车 \(time(journey.departure)) · 到站 \(time(journey.targetArrival))")
                            Text("最晚出发 \(time(journey.latestStart))")
                        }
                    } else {
                        Text("保存返程计划后显示时间")
                    }
                }
                .font(.caption2).monospacedDigit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { Color.clear }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    Text("途鹿旅游").font(.caption.weight(.bold)).foregroundStyle(Color(red: 0.13, green: 0.43, blue: 0.44))
                    if let journey = entry.journey {
                        Text(journey.station).font(.headline).lineLimit(1)
                        if let start = journey.plannedStart, let arrival = journey.bufferedArrival {
                            Text(time(start)).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("计划出发 · 含缓冲到站 \(time(arrival))").font(.caption).monospacedDigit()
                            Text("发车 \(time(journey.departure)) · 最晚 \(time(journey.latestStart))").font(.caption2).monospacedDigit()
                        } else {
                            Text(time(journey.departure)).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("最晚出发 \(time(journey.latestStart))").font(.caption).monospacedDigit()
                            Text("建议到站 \(time(journey.targetArrival))").font(.caption).monospacedDigit()
                        }
                    } else {
                        Spacer(minLength: 2)
                        Text("暂无返程计划").font(.headline)
                        Text("在 App 中保存后显示").font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { Color(red: 0.95, green: 0.97, blue: 0.96) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct JourneyWidget: Widget {
    let kind = "LvYouXuJourneyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JourneyProvider()) { entry in
            JourneyWidgetView(entry: entry)
        }
        .configurationDisplayName("途鹿旅游返程时间")
        .description("显示下一份返程计划的关键时刻")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

@main
struct JourneyWidgetBundle: WidgetBundle {
    var body: some Widget { JourneyWidget() }
}
