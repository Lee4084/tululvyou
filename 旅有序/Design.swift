import SwiftUI

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

enum Wayfinding {
    static func background(_ dark: Bool) -> Color { Color(hex: dark ? 0x0E0F11 : 0xF3F3F2) }
    static func surface(_ dark: Bool) -> Color { Color(hex: dark ? 0x1B1C1F : 0xFFFFFF) }
    static func raised(_ dark: Bool) -> Color { Color(hex: dark ? 0x292B2E : 0xE9EAEB) }
    static func ink(_ dark: Bool) -> Color { Color(hex: dark ? 0xF4F4F2 : 0x202124) }
    static func muted(_ dark: Bool) -> Color { Color(hex: dark ? 0xAFB1B5 : 0x606269) }
    static func line(_ dark: Bool) -> Color { Color(hex: dark ? 0x3C3E42 : 0xD8DADD) }
    static func teal(_ dark: Bool) -> Color { Color(hex: dark ? 0xD4D6D9 : 0x565B61) }
    static func deepTeal(_ dark: Bool) -> Color { Color(hex: dark ? 0xF0F0EE : 0x2C3035) }
    static func wash(_ dark: Bool) -> Color { Color(hex: dark ? 0x2B2D31 : 0xE9EAEB) }
    static func amber(_ dark: Bool) -> Color { Color(hex: dark ? 0xD9B184 : 0x875D36) }
    static func amberWash(_ dark: Bool) -> Color { Color(hex: dark ? 0x393027 : 0xF4EBE2) }
    static func red(_ dark: Bool) -> Color { Color(hex: dark ? 0xE49893 : 0xA54D4A) }
    static func green(_ dark: Bool) -> Color { Color(hex: dark ? 0xB8C8BA : 0x4C6553) }
}

struct PageTitle: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 38
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: titleSize, weight: .bold, design: .rounded)).foregroundStyle(Wayfinding.ink(scheme == .dark))
            if let subtitle { Text(subtitle).font(.body).foregroundStyle(Wayfinding.muted(scheme == .dark)) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
    }
}

struct WayCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var tint = false
    @ViewBuilder var content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(tint ? Wayfinding.wash(scheme == .dark) : Wayfinding.surface(scheme == .dark), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Wayfinding.line(scheme == .dark), lineWidth: 1))
    }
}

struct WayButton: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var filled = true
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 52) }
            .buttonStyle(.plain)
            .foregroundStyle(filled ? Wayfinding.background(scheme == .dark) : Wayfinding.deepTeal(scheme == .dark))
            .background(filled ? Wayfinding.deepTeal(scheme == .dark) : Wayfinding.surface(scheme == .dark), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Wayfinding.deepTeal(scheme == .dark), lineWidth: 1))
            .opacity(disabled ? 0.45 : 1).disabled(disabled)
    }
}

struct StatusBadge: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    var warning = false
    var body: some View {
        Text(title).font(.footnote.weight(.semibold)).padding(.horizontal, 11).padding(.vertical, 7)
            .foregroundStyle(warning ? Wayfinding.amber(scheme == .dark) : Wayfinding.teal(scheme == .dark))
            .background(warning ? Wayfinding.amberWash(scheme == .dark) : Wayfinding.wash(scheme == .dark), in: Capsule())
    }
}

struct ValueText: View {
    @Environment(\.colorScheme) private var scheme
    let value: String
    var emphasized = false
    var body: some View {
        Text(value).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
            .foregroundStyle(emphasized ? Wayfinding.teal(scheme == .dark) : Wayfinding.ink(scheme == .dark))
            .minimumScaleFactor(0.8)
    }
}

struct NewPlanButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(.black.opacity(0.08))
                        .frame(width: 45, height: 45)
                        .scaleEffect(breathing ? 1.12 : 1)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                Text("新建返程计划")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 19, weight: .semibold))
                    .offset(y: breathing ? -2 : 1)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 78)
            .foregroundStyle(Color.black)
            .background(
                LinearGradient(colors: [.white, Color(red: 0.83, green: 0.84, blue: 0.86)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.65), lineWidth: 1))
            .shadow(color: .white.opacity(0.10), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新建返程计划")
        .accessibilityHint("打开返程信息填写页")
        .onAppear {
            guard !reduceMotion && !ProcessInfo.processInfo.arguments.contains("--ui-testing-no-animation") else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

struct PageScroll<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(20)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Wayfinding.background(scheme == .dark)
                .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
    }
}
