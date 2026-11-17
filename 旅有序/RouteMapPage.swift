import SwiftUI
import MapKit
import SafariServices

private enum RouteMode: String, CaseIterable, Identifiable {
    case transit = "公共交通"
    case driving = "打车／驾车"
    case walking = "步行"

    var id: String { rawValue }
    var transportType: MKDirectionsTransportType {
        switch self {
        case .transit: .transit
        case .driving: .automobile
        case .walking: .walking
        }
    }
    var uriMode: String {
        switch self {
        case .transit: "bus"
        case .driving: "car"
        case .walking: "walk"
        }
    }
}

struct RouteMapPage: View {
    @EnvironmentObject private var store: PlanStore
    let id: UUID

    @State private var position: MapCameraPosition = .automatic
    @State private var mode: RouteMode = .transit
    @State private var origin: MKMapItem?
    @State private var station: MKMapItem?
    @State private var route: MKRoute?
    @State private var resolvedStops: [MKMapItem] = []
    @State private var stopIssue: String?
    @State private var candidates: [MKMapItem] = []
    @State private var selectingStation = true
    @State private var loadingText: String?
    @State private var issue: String?
    @State private var showTransitMap = false

    var body: some View {
        PageScroll {
            if let plan = store.plan(id) {
                PageTitle(title: "真实路线图", subtitle: "\(plan.startPlace) → \(plan.stationPlace)")
                if !plan.activities.isEmpty {
                    WayCard {
                        Text(resolvedStops.count == plan.activities.count
                             ? "已在地图标记\(resolvedStops.count)个中途地点。彩色连线只表示经过顺序，不是道路或公交导航路线。"
                             : stopIssue == nil
                               ? "已添加\(plan.activities.count)站中途行程。正在核对地点；未确认前保留原来的起点到车站地图。"
                               : "中途地点暂未明确匹配，地图保留原来的起点到车站路线。")
                            .font(.subheadline)
                    }
                }
                WayCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("出行方式").font(.headline)
                        Picker("出行方式", selection: $mode) {
                            ForEach(RouteMode.allCases) { option in Text(option.rawValue).tag(option) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Map(position: $position) {
                    if let origin { Marker("出发", coordinate: origin.placemark.coordinate) }
                    if let station { Marker("车站", coordinate: station.placemark.coordinate) }
                    if resolvedStops.count == plan.activities.count, !resolvedStops.isEmpty {
                        ForEach(resolvedStops.indices, id: \.self) { index in
                            Marker("第\(index + 1)站 · \(plan.activities[index].title.isEmpty ? plan.activities[index].place : plan.activities[index].title)",
                                   coordinate: resolvedStops[index].placemark.coordinate)
                                .tint(.orange)
                        }
                        MapPolyline(coordinates: stopRouteCoordinates)
                            .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [9, 7]))
                    } else if let route {
                        MapPolyline(route.polyline).stroke(Wayfinding.ink(true), lineWidth: 5)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityLabel(resolvedStops.isEmpty ? "从出发地点到车站的路线地图" : "按出发、中途各站、车站顺序标记的地图")

                if let loadingText { WayCard { ProgressView(loadingText) } }
                if let issue { IssueBanner(text: issue) }
                if let stopIssue { WayCard { Text(stopIssue).font(.subheadline).foregroundStyle(.orange) } }
                if !resolvedStops.isEmpty, resolvedStops.count == plan.activities.count {
                    WayCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("地图站点顺序").font(.headline)
                            Text(([plan.startPlace] + plan.activities.map(\.place) + [plan.stationPlace]).joined(separator: " → "))
                                .font(.body)
                            Text("这些点的位置来自 Apple 地图搜索；交通时间仍按你填写的数值计算。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                if !candidates.isEmpty {
                    WayCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectingStation ? "请选择车票上的车站" : "请选择实际出发地点")
                                .font(.headline)
                            ForEach(candidates.indices, id: \.self) { index in
                                Button { choose(candidates[index], plan: plan) } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidates[index].name ?? "未命名地点").font(.body.weight(.semibold))
                                        Text(candidates[index].placemark.title ?? "地址待核对")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                if index != candidates.count - 1 { Divider() }
                            }
                        }
                    }
                }

                if let route {
                    WayCard(tint: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("地图路线").font(.headline)
                            Text("\(mode.rawValue) · 约\(Int(ceil(route.expectedTravelTime / 60)))分钟 · \(String(format: "%.1f", route.distance / 1000))公里")
                            Text("计划仍按你填写的\(plan.finalTravel.map(String.init) ?? "待补全")分钟交通时间计算；地图估时不含你额外预留的路上缓冲。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if origin != nil && station != nil {
                    WayCard(tint: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mode == .transit ? "公共交通路线" : "更多路线方案").font(.headline)
                            Text(plan.activities.isEmpty
                                 ? "已找到起点和车站。点下方按钮，在高德地图查看\(mode.rawValue)路线。"
                                 : "下方高德入口目前只打开起点到车站的路线；中途各站请按地图顺序逐段核对。")
                                .font(.body)
                            Text("网页若询问定位，可选“不允许”；打开后请核对地点与班次。计划仍按手填交通用时计算。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    WayButton(title: "在高德查看\(mode.rawValue)路线") { showTransitMap = true }
                }
                if station != nil || origin != nil {
                    WayButton(title: "重新核对地点", filled: false) { resetAndSearch(plan) }
                }
                Text("地点搜索与底图由 Apple 地图提供，路线方案可能由高德提供；均需要网络。请核对起点、车站和车票，路况与班次可能变化。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                IssueBanner(text: "未找到这份计划，请返回计划页重试。")
            }
        }
        .navigationTitle("查看路线").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: id) {
            if let plan = store.plan(id) { await searchStation(plan) }
        }
        .onChange(of: mode) { _, _ in
            if let plan = store.plan(id), origin != nil, station != nil {
                Task { await calculate(plan) }
            }
        }
        .sheet(isPresented: $showTransitMap) {
            if let url = routeURL { TransitBrowser(url: url) }
        }
    }

    private func resetAndSearch(_ plan: Plan) {
        origin = nil
        station = nil
        route = nil
        resolvedStops = []
        stopIssue = nil
        candidates = []
        issue = nil
        Task { await searchStation(plan) }
    }

    private func choose(_ item: MKMapItem, plan: Plan) {
        candidates = []
        if selectingStation {
            station = item
            position = .region(MKCoordinateRegion(center: item.placemark.coordinate,
                                                   span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))
            Task { await searchOrigin(plan) }
        } else {
            origin = item
            position = .automatic
            Task {
                await resolveStops(plan)
                await calculate(plan)
            }
        }
    }

    private func searchStation(_ plan: Plan) async {
        guard !plan.stationPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issue = "请先填写乘车站。"
            return
        }
        selectingStation = true
        loadingText = "正在查找车站"
        issue = nil
        do {
            let found = try await search(plan.stationPlace, near: nil)
            present(found, query: plan.stationPlace, plan: plan)
        } catch {
            issue = "车站搜索失败，请检查网络后重试。"
        }
        loadingText = nil
    }

    private func searchOrigin(_ plan: Plan) async {
        guard let station else { return }
        guard !plan.startPlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            issue = "请先填写出发地点。"
            return
        }
        selectingStation = false
        loadingText = "正在查找出发地点"
        issue = nil
        let nearby = MKCoordinateRegion(center: station.placemark.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3))
        do {
            let found = try await search(plan.startPlace, near: nearby)
            present(found, query: plan.startPlace, plan: plan)
        } catch {
            issue = "出发地点搜索失败，请检查网络后重试。"
        }
        loadingText = nil
    }

    private func search(_ query: String, near region: MKCoordinateRegion?) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        return Array(response.mapItems.prefix(5))
    }

    private func present(_ items: [MKMapItem], query: String, plan: Plan) {
        guard !items.isEmpty else {
            issue = selectingStation ? "没有找到车站，请把车站名称写得更完整。" : "没有找到出发地点，请填写更具体的地点名称或地址。"
            return
        }
        let exact = items.filter { ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == query.trimmingCharacters(in: .whitespacesAndNewlines) }
        if exact.count == 1 { choose(exact[0], plan: plan) }
        else if items.count == 1 { choose(items[0], plan: plan) }
        else { candidates = items }
    }

    private func calculate(_ plan: Plan) async {
        guard let origin, let station else { return }
        if !plan.activities.isEmpty, resolvedStops.count == plan.activities.count {
            route = nil
            issue = nil
            loadingText = nil
            return
        }
        if mode == .transit {
            route = nil
            issue = nil
            loadingText = nil
            return
        }
        loadingText = "正在绘制\(mode.rawValue)路线"
        issue = nil
        route = nil
        let request = MKDirections.Request()
        request.source = origin
        request.destination = station
        request.transportType = mode.transportType
        if let departure = minutesDate(plan.day, Calculation.run(plan).latestStart), departure > Date() {
            request.departureDate = departure
        }
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let first = response.routes.first else {
                issue = "地图暂未提供这段\(mode.rawValue)路线，请切换出行方式。"
                loadingText = nil
                return
            }
            route = first
            position = .rect(first.polyline.boundingMapRect)
        } catch {
            issue = "Apple 地图暂未提供这段\(mode.rawValue)路线，可使用下方高德路线或切换出行方式。"
        }
        loadingText = nil
    }

    private var stopRouteCoordinates: [CLLocationCoordinate2D] {
        guard let origin, let station else { return [] }
        return [origin.placemark.coordinate] + resolvedStops.map { $0.placemark.coordinate } + [station.placemark.coordinate]
    }

    private func resolveStops(_ plan: Plan) async {
        resolvedStops = []
        stopIssue = nil
        guard !plan.activities.isEmpty, let origin, station != nil else { return }
        loadingText = "正在核对中途地点"
        var foundStops: [MKMapItem] = []
        for (index, activity) in plan.activities.enumerated() {
            let query = activity.place.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                stopIssue = "第\(index + 1)站还没有地点，地图暂时保留原来的路线。"
                loadingText = nil
                return
            }
            let near = foundStops.last?.placemark.coordinate ?? origin.placemark.coordinate
            let region = MKCoordinateRegion(center: near,
                                            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3))
            do {
                let candidates = try await search(query, near: region)
                let exact = candidates.filter {
                    ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == query
                }
                guard let chosen = exact.count == 1 ? exact[0] : (candidates.count == 1 ? candidates[0] : nil) else {
                    stopIssue = "第\(index + 1)站“\(query)”未找到唯一地点，暂时保留原来的路线；可在计划里写更具体的名称。"
                    loadingText = nil
                    return
                }
                foundStops.append(chosen)
            } catch {
                stopIssue = "中途地点暂时无法搜索，地图保留原来的路线；请检查网络后重试。"
                loadingText = nil
                return
            }
        }
        resolvedStops = foundStops
        let coordinates = stopRouteCoordinates
        if let first = coordinates.first {
            let latitudes = coordinates.map(\.latitude)
            let longitudes = coordinates.map(\.longitude)
            let minLatitude = latitudes.min() ?? first.latitude
            let maxLatitude = latitudes.max() ?? first.latitude
            let minLongitude = longitudes.min() ?? first.longitude
            let maxLongitude = longitudes.max() ?? first.longitude
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2,
                                               longitude: (minLongitude + maxLongitude) / 2),
                span: MKCoordinateSpan(latitudeDelta: max(0.03, (maxLatitude - minLatitude) * 1.5),
                                       longitudeDelta: max(0.03, (maxLongitude - minLongitude) * 1.5))))
        }
        loadingText = nil
    }

    private var routeURL: URL? {
        guard let origin, let station else { return nil }
        let from = origin.placemark.coordinate
        let to = station.placemark.coordinate
        var components = URLComponents(string: "https://uri.amap.com/navigation")
        components?.queryItems = [
            URLQueryItem(name: "from", value: String(format: "%.6f,%.6f,%@", from.longitude, from.latitude, origin.name ?? "出发地点")),
            URLQueryItem(name: "to", value: String(format: "%.6f,%.6f,%@", to.longitude, to.latitude, station.name ?? "乘车站")),
            URLQueryItem(name: "mode", value: mode.uriMode),
            URLQueryItem(name: "coordinate", value: "wgs84"),
            URLQueryItem(name: "src", value: "TuLuTravel"),
            URLQueryItem(name: "callnative", value: "0")
        ]
        return components?.url
    }
}

private struct TransitBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
