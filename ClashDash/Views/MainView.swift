import SwiftUI

struct MainView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var networkMonitor = NetworkMonitor()
    @ObservedObject var appManager = AppManager.shared
    @State private var selectedTab = 0
     
    var body: some View {
        TabView(selection: $selectedTab) {
            // 概览标签页
            NavigationStack {
                OverviewTab()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text("Overview").font(.headline)
                                ServerPickerView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(0)
            // 代理标签页
            NavigationStack {
                ProxiesTab()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text("Proxies").font(.headline)
                                ServerPickerView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("Proxies", systemImage: "globe")
            }
            .tag(1)

            // 规则标签页
            NavigationStack {
                RulesTab()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text("Rules").font(.headline)
                                ServerPickerView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("Rules", systemImage: "ruler")
            }
            .tag(2)

            // 连接标签页
            NavigationStack {
                ConnectionsTab()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text("Connections").font(.headline)
                                ServerPickerView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("Connections", systemImage: "link")
            }
            .tag(3)

            // 更多标签页
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text("Settings").font(.headline)
                                ServerPickerView()
                            }
                        }
                    }
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            .tag(4)
        }
        .navigationTitle(appManager.appName)
        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//
//            ToolbarItem(placement: .topBarLeading) {
//                Button {
//                    
//                } label: {
//                    Image(systemName: "chevron.left")
//                }
//            }
//
//            ToolbarItem(placement: .principal) {
//                Text("aaa")
//            }
//        }
        .onAppear {
            networkMonitor.startMonitoring(server: appManager.currentServer)
        }
        .onDisappear {
            networkMonitor.stopMonitoring()
        }
        .onChange(of: appManager.currentServer) { oldServer, newServer in
            networkMonitor.restartMonitoring(server: newServer)
        }

    }
}

// 添加 UIVisualEffectView 包装器
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// 状态卡片组件
struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// 图表卡片组件
struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
