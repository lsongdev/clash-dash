import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var appManager = AppManager.shared
    @State private var showingWelcome: Bool

    init() {
        _showingWelcome = State(initialValue: AppManager.shared.servers.isEmpty)
    }

    var body: some View {
        Group {
            if showingWelcome {
                WelcomeView { showingWelcome = false }
            }
            else { MainView() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appManager.suspendDemoServer()
            case .active: appManager.resumeDemoServer()
            default: break
            }
        }
        .tint(appManager.appTintColor.getColor())
        .preferredColorScheme(appManager.colorSchemeMode.getColorScheme())
    }
}

struct WelcomeView: View {
    @ObservedObject private var appManager = AppManager.shared
    var onGetStarted: () -> Void = {}
    private var icon: UIImage? {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let names = primary?["CFBundleIconFiles"] as? [String]
        return names?.last.flatMap { UIImage(named: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .center, spacing: 18) {
                    Group {
                        if let icon { Image(uiImage: icon).resizable().scaledToFit() }
                        else { Image(systemName: "network").resizable().scaledToFit().padding(22).foregroundStyle(appManager.appTintColor.getColor()) }
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .accessibilityHidden(true)

                    Text("ClashHandy")
                        .font(.largeTitle.bold())
                    Text("Your network, at a glance.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("A simple dashboard for your Clash-compatible servers. Monitor traffic, choose proxies, and manage rules — all in one place.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 24) {
                    feature("Live insights", description: "See traffic, memory, and active connections.", icon: "chart.xyaxis.line")
                    feature("Simple controls", description: "Switch nodes, test latency, and manage rules.", icon: "slider.horizontal.3")
                    feature("Try it first", description: "Explore a local demo with fictional data. No server or account needed.", icon: "play.circle")
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 48)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button("Get started") {
                    guard appManager.demoServer.status == .ok else { return }
                    appManager.addDemoServer()
                    onGetStarted()
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(appManager.appTintColor.getColor(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(appManager.appTintColor == .monochrome ? Color(.systemBackground) : .white)
                    .disabled(appManager.demoServer.status != .ok)
                Text(appManager.demoServer.errorMessage ?? "Starts with Demo Server. Add your own server anytime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func feature(_ title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(appManager.appTintColor.getColor())
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview { WelcomeView() }
