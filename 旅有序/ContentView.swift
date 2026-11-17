import SwiftUI

enum Route: Hashable {
    case create, createTemplate(Int), editBasics(UUID), timeline(UUID), routeMap(UUID), reminder(UUID), activity(UUID, Int), check(UUID), adjust(UUID), compare(UUID, Int), record(UUID), myRecords, templates, pdf(UUID), settings, help, privacy, agreement
}
struct ContentView: View {
    @StateObject private var store = PlanStore()
    @StateObject private var wishes = WishStore()
    @State private var tab = 0
    @State private var showWelcome = true
    @State private var startupRoute: Route? = nil
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if showWelcome {
                WelcomePage { route in
                    startupRoute = route
                    tab = 0
                    showWelcome = false
                }
            } else {
                TabView(selection: $tab) {
                    AppNavigation(tab: 0, tabSelection: $tab, startupRoute: $startupRoute).tabItem { Label("计划", systemImage: "list.bullet.rectangle") }.tag(0)
                    AppNavigation(tab: 1, tabSelection: $tab, startupRoute: $startupRoute).tabItem { Label("进行中", systemImage: "clock") }.tag(1)
                    AppNavigation(tab: 2, tabSelection: $tab, startupRoute: $startupRoute).tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(2)
                }
            }
        }
        .environmentObject(store)
        .environmentObject(wishes)
        .background(WindowKeyboardDismissInstaller().frame(width: 0, height: 0))
        .fontDesign(.rounded)
        .tint(Wayfinding.teal(true))
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshWidget()
                Task { await ReminderCenter.shared.enqueueReconcile(plans: store.plans) }
            }
        }
    }
}
struct AppNavigation: View {
    @EnvironmentObject private var store: PlanStore
    let tab: Int
    @Binding var tabSelection: Int
    @Binding var startupRoute: Route?
    @State private var path: [Route] = []
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch tab {
                case 0: PlansPage { path.append($0) }
                case 1: ActivePage { path.append($0) }
                default: PersonalCenterPage { path.append($0) }
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(route).toolbar(.hidden, for: .tabBar)
            }
            .onAppear { openStartupRoute() }
            .onChange(of: startupRoute) { _, route in if tab == 0, let route { path.append(route); startupRoute = nil } }
        }
    }
    private func openStartupRoute() {
        if tab == 0, let startupRoute {
            path.append(startupRoute)
            self.startupRoute = nil
        }
    }
    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .create: BasicPage(template: nil, editingID: nil) { id in path.append(.timeline(id)) }
        case .createTemplate(let template): BasicPage(template: template, editingID: nil) { id in path.append(.timeline(id)) }
        case .editBasics(let id): BasicPage(template: nil, editingID: id) { _ in }
        case .timeline(let id): TimelinePage(id: id) { path.append($0) } onActive: { tabSelection = 1 }
        case .routeMap(let id): RouteMapPage(id: id)
        case .reminder(let id): ReminderPage(id: id)
        case .activity(let id, let index): ActivityPage(id: id, index: index)
        case .check(let id): CheckPage(id: id) { path.append($0) }
        case .adjust(let id): AdjustPage(id: id) { path.append($0) }
        case .compare(let id, let minutes): ComparePage(id: id, minutes: minutes) { path.removeLast(min(2, path.count)) }
        case .record(let id): RecordDetailPage(id: id) { path.append($0) }
        case .myRecords: MyJourneyRecordsPage { path.append($0) }
        case .templates: TemplatesPage { path.append($0) }
        case .pdf(let id): PDFPage(id: id)
        case .settings: SettingsPage { path.append($0) }
        case .help: HelpPage()
        case .privacy: LegalPage(kind: .privacy)
        case .agreement: LegalPage(kind: .agreement)
        }
    }
}
