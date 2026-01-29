import SwiftUI

struct ServerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var selectedTab = 0
    
    @State var server: ClashServer
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 概览标签页
            NavigationStack {
                OverviewTab(server: server)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            ServerPickerMenu()
                        }
                    }
            }
            .tabItem {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(0)
            // 代理标签页
            NavigationStack {
                ProxiesTab(server: server)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            ServerPickerMenu()
                        }
                    }
            }
            .tabItem {
                Label("Proxies", systemImage: "globe")
            }
            .tag(1)
            
            // 规则标签页
            NavigationStack {
                RulesTab(server: server)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            ServerPickerMenu()
                        }
                    }
            }
            .tabItem {
                Label("Rules", systemImage: "ruler")
            }
            .tag(2)
            
            // 连接标签页
            NavigationStack {
                ConnectionsView(server: server)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            ServerPickerMenu()
                        }
                    }
            }
            .tabItem {
                Label("Connections", systemImage: "link")
            }
            .tag(3)
            
            // 更多标签页
            NavigationStack {
                SettingsView(server: server)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            ServerPickerMenu()
                        }
                    }
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            .tag(4)
        }
        .navigationTitle(server.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            networkMonitor.startMonitoring(server: server)
        }
        .onDisappear {
            networkMonitor.stopMonitoring()
        }
        
    }
}

// 服务器选择器（Menu 或 Sheet 方式）
struct ServerPickerMenu: View {
    @State private var showSheet = false
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Image(systemName: "server.rack")
                Text("server 1")
                    .lineLimit(1)
            }
        }
        .sheet(isPresented: $showSheet) {
            ServerListView()
                .presentationDetents([.medium, .large])
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

// 辅助视图组件
struct ProxyGroupRow: View {
    @State private var selectedProxy = "Auto"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("代理组名称")
                .font(.headline)
            
            Picker("选择理", selection: $selectedProxy) {
                Text("Auto").tag("Auto")
                Text("香港 01").tag("HK01")
                Text("新加坡 01").tag("SG01")
                Text("日本 01").tag("JP01")
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 4)
    }
}
 
