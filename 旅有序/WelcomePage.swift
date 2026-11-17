import SwiftUI

struct WelcomePage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = 42
    let done: (Route?) -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image("BrandIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        Text("途鹿旅游")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .tracking(3)
                        Spacer()
                        Text("返程日助手")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer(minLength: 30)

                    Text("把返程的每一步\n安排得刚刚好。")
                        .font(.system(size: heroSize, weight: .bold, design: .rounded))
                        .fontWeight(.bold)
                        .lineSpacing(8)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("时间提醒与路线查看，出发前一眼看清。")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.64))
                        .padding(.top, 15)

                    WelcomeRoutePreview(animated: !reduceMotion && !ProcessInfo.processInfo.arguments.contains("--ui-testing-no-animation"))
                        .frame(height: 254)
                        .padding(.top, 33)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("路线示意，从出发地前往车站。可在计划中查看真实路线。")

                    HStack(spacing: 11) {
                        WelcomeFeature(symbol: "bell.badge", title: "时间提醒", detail: "关键时刻清楚可见")
                        WelcomeFeature(symbol: "map", title: "路线查看", detail: "去车站路线随时看")
                    }
                    .padding(.top, 12)

                    Spacer(minLength: 24)

                    Button { done(nil) } label: {
                        HStack {
                            Text("进入途鹿旅游")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 22)
                        .frame(height: 56)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        Button("新建返程计划") { done(.create) }
                        Button("先看示例") { done(.timeline(Plan.demoID)) }
                    }
                    .font(.body.weight(.semibold))
                    .buttonStyle(WelcomeSecondaryButtonStyle())
                    .padding(.top, 11)

                    Text("无需账号 · 计划保存在本机")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 19)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack {
                    Color(red: 0.055, green: 0.060, blue: 0.068)
                    RadialGradient(colors: [Color.white.opacity(0.09), .clear], center: .init(x: 0.92, y: 0.26), startRadius: 5, endRadius: 330)
                }.ignoresSafeArea()
            }
        }
    }
}

private struct WelcomeFeature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .light))
                .frame(height: 25)
                .accessibilityHidden(true)
            Text(title).font(.body.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
        .padding(15)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.10)))
        .accessibilityElement(children: .combine)
    }
}

private struct WelcomeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 47)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.65 : 0.9))
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.055), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.14)))
    }
}

private struct WelcomeRoutePreview: View {
    let animated: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.11, green: 0.12, blue: 0.13))
                grid(in: geometry.size)
                    .stroke(.white.opacity(0.055), lineWidth: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                route(in: geometry.size)
                    .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                route(in: geometry.size)
                    .trim(from: 0, to: progress)
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Circle().fill(Color.white).frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.65), lineWidth: 3))
                    .position(x: width * 0.17, y: height * 0.67)
                Circle().fill(Color.white.opacity(0.12)).frame(width: 31, height: 31)
                    .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 2))
                    .overlay(Image(systemName: "tram.fill").font(.system(size: 12)))
                    .position(x: width * 0.82, y: height * 0.44)

                VStack(alignment: .leading, spacing: 5) {
                    Text("路线示意")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .tracking(2)
                    Text("从出发地，到车站")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                    Spacer()
                    HStack {
                        Label("出发地", systemImage: "location.fill")
                        Spacer()
                        Label("车站", systemImage: "tram.fill")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
                }
                .padding(22)
            }
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
            .onAppear {
                if animated {
                    withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { progress = 1 }
                } else {
                    progress = 1
                }
            }
        }
    }

    private func route(in size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.17, y: size.height * 0.67))
            path.addCurve(
                to: CGPoint(x: size.width * 0.82, y: size.height * 0.44),
                control1: CGPoint(x: size.width * 0.39, y: size.height * 0.93),
                control2: CGPoint(x: size.width * 0.51, y: size.height * 0.28)
            )
        }
    }

    private func grid(in size: CGSize) -> Path {
        Path { path in
            for fraction in stride(from: 0.12, through: 0.95, by: 0.17) {
                let x = size.width * fraction
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x - size.width * 0.16, y: size.height))
            }
            for fraction in stride(from: 0.18, through: 0.9, by: 0.2) {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + size.height * 0.08))
            }
        }
    }
}
