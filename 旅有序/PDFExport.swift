import Foundation
import UIKit

struct PDFExport {
    static func make(plan: Plan, detailed: Bool, addresses: Bool, notes: Bool) throws -> URL {
        let calculation = Calculation.run(plan)
        let generated = Date()
        let filename = "途鹿旅游-\(plan.id.uuidString)-\(plan.revision).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try renderer.writePDF(to: url) { context in
            let body = UIFont.systemFont(ofSize: 13)
            let heading = UIFont.systemFont(ofSize: 22, weight: .semibold)
            let lineHeight: CGFloat = 25
            var y: CGFloat = 0
            var page = 0
            func beginPage() {
                context.beginPage(); page += 1; y = 48
                ("途鹿旅游 · 时间卡" as NSString).draw(at: CGPoint(x: 44, y: y), withAttributes: [.font: heading]); y += 43
            }
            func line(_ value: String) {
                let rectangle = CGRect(x: 44, y: y, width: 507, height: 1000)
                let measured = (value as NSString).boundingRect(with: CGSize(width: 507, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: body], context: nil)
                let height = max(lineHeight, measured.height + 7)
                if y + height > 775 { beginPage() }
                (value as NSString).draw(in: CGRect(x: rectangle.minX, y: y, width: rectangle.width, height: height), withAttributes: [.font: body])
                y += height
            }
            beginPage()
            line(plan.displayTitle)
            line("日期 \(dayText(plan.day)) · \(plan.city) · \(plan.status.label)")
            line("目标到站 \(clockText(plan.targetArrival))")
            line("物理预计到站 \(clockText(calculation.physical))")
            line("预计到站（含\(plan.buffer)分钟缓冲） \(clockText(calculation.buffered))")
            line(calculation.margin.map { $0 > 0 ? "估时余量\($0)分钟" : $0 == 0 ? "恰好到目标，额外余量为0。" : "比目标晚\(-$0)分钟" } ?? "信息未完整，完整结果待补全")
            line("行程")
            for activity in plan.activities {
                line("• \(activity.title.isEmpty ? activity.kind.label : activity.title) · \(activity.duration.map(String.init) ?? "待补全")分钟 · \(activity.required ? "必须" : "可选")")
                if detailed {
                    line("  地点：\(activity.place)")
                    line("  入站交通：\(activity.samePlace ? "同地点" : activity.incomingMinutes.map { "\($0)分钟" } ?? "待补全")")
                }
            }
            line("去车站的交通 \(plan.finalSamePlace ? "同地点" : plan.finalTravel.map { "\($0)分钟" } ?? "待补全")")
            if let arrival = plan.actualArrival { line("实际到站 \(timeText(arrival))") }
            if detailed && !plan.changeNotes.isEmpty { line("变更记录"); for change in plan.changeNotes { line("• \(change)") } }
            if notes && !plan.notes.isEmpty { line("备注：\(plan.notes)") }
            let formatter = DateFormatter(); formatter.timeZone = chinaZone; formatter.dateFormat = "yyyy-MM-dd HH:mm"
            line("生成于 \(formatter.string(from: generated)) · 版本 \(plan.revision) · 第\(page)页")
            line("按填写时长估算，不含实时路况。此文件是静态阅读副本，不会随行程更新，不能恢复App内计划。")
            _ = addresses
        }
        return url
    }
}
