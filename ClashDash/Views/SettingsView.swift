import SwiftUI

struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingUpgradeAlert = false
    @State private var showingRestartAlert = false
    
    let server: ClashServer
    
    var body: some View {
        NavigationStack {
            List {
                
                // 常规设置
                Section("常规设置") {
                    Picker("运行模式", selection: $viewModel.mode) {
                        Text("规则模式").tag("rule")
                        Text("全局模式").tag("global")
                        Text("直连模式").tag("direct")
                        Text("脚本模式").tag("script")
                    }
                    .onChange(of: viewModel.mode) { newValue in
                        viewModel.updateConfig("mode", value: newValue, server: server)
                    }
                    
                    
                    
                    Picker("日志等级", selection: $viewModel.logLevel) {
                        Text("调试").tag("debug")
                        Text("信息").tag("info")
                        Text("警告").tag("warning")
                        Text("错误").tag("error")
                        Text("静默").tag("silent")
                    }
                    .onChange(of: viewModel.logLevel) { newValue in
                        viewModel.updateConfig("log-level", value: newValue, server: server)
                    }
                    NavigationLink {
                        LogView(server: server)
                    } label: {
                        Text("日志查询")
                    }
                    
                    NavigationLink {
                        DNSQueryView(server: server)
                    } label: {
                        Text("DNS查询")
                    }
                    
                }
                
                // 端口设置
                Section("端口设置") {
                    PortSettingRow(
                        title: "HTTP 端口",
                        value: $viewModel.tempHttpPort,
                        savedValue: viewModel.httpPort,
                        configKey: "port"
                    ) { newValue in
                        if viewModel.validateAndUpdatePort(newValue, configKey: "port", server: server) {
                            viewModel.httpPort = newValue
                        }
                    }
                    
                    PortSettingRow(
                        title: "Socks5 端口",
                        value: $viewModel.tempSocksPort,
                        savedValue: viewModel.socksPort,
                        configKey: "socks-port"
                    ) { newValue in
                        if viewModel.validateAndUpdatePort(newValue, configKey: "socks-port", server: server) {
                            viewModel.socksPort = newValue
                        }
                    }
                    
                    PortSettingRow(
                        title: "混合端口",
                        value: $viewModel.tempMixedPort,
                        savedValue: viewModel.mixedPort,
                        configKey: "mixed-port"
                    ) { newValue in
                        if viewModel.validateAndUpdatePort(newValue, configKey: "mixed-port", server: server) {
                            viewModel.mixedPort = newValue
                        }
                    }
                    
                    PortSettingRow(
                        title: "重定向端口",
                        value: $viewModel.tempRedirPort,
                        savedValue: viewModel.redirPort,
                        configKey: "redir-port"
                    ) { newValue in
                        if viewModel.validateAndUpdatePort(newValue, configKey: "redir-port", server: server) {
                            viewModel.redirPort = newValue
                        }
                    }
                    
                    PortSettingRow(
                        title: "TProxy 端口",
                        value: $viewModel.tempTproxyPort,
                        savedValue: viewModel.tproxyPort,
                        configKey: "tproxy-port"
                    ) { newValue in
                        if viewModel.validateAndUpdatePort(newValue, configKey: "tproxy-port", server: server) {
                            viewModel.tproxyPort = newValue
                        }
                    }
                    
                    Toggle("允许局域网连接", isOn: $viewModel.allowLan)
                        .onChange(of: viewModel.allowLan) { newValue in
                            viewModel.updateConfig("allow-lan", value: newValue, server: server)
                        }
                }
                
                // TUN 设置
                if viewModel.config?.isMetaServer == true {
                    Section("TUN 设置") {
                        Toggle("启用 TUN 模式", isOn: $viewModel.tunEnable)
                            .onChange(of: viewModel.tunEnable) { newValue in
                                viewModel.updateConfig("tun.enable", value: newValue, server: server)
                            }
                        
                        HStack {
                            Text("TUN 协议栈")
                            Spacer()
                            Picker("", selection: $viewModel.tunStack) {
                                Text("gVisor").tag("gVisor")
                                Text("Mixed").tag("mixed")
                                Text("System").tag("system")
                            }
                            .pickerStyle(.menu)
                            .onChange(of: viewModel.tunStack) { newValue in
                                viewModel.updateConfig("tun.stack", value: newValue, server: server)
                            }
                        }
                        
                        HStack {
                            Text("设备名称")
                            Spacer()
                            TextField("utun", text: $viewModel.tunDevice)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: viewModel.tunDevice) { newValue in
                                    viewModel.updateConfig("tun.device", value: newValue, server: server)
                                }
                        }
                        
                        HStack {
                            Text("网卡名称")
                            Spacer()
                            TextField("", text: $viewModel.interfaceName)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: viewModel.interfaceName) { newValue in
                                    viewModel.updateConfig("interface-name", value: newValue, server: server)
                                }
                        }
                    }
                    
                    Section {
                        NavigationLink("Appearance", destination: AppearanceView())
                        NavigationLink("About", destination: AboutView())
                    }
                    
                    // 系统维护
                    Section("系统维护") {
                        Button(action: { viewModel.reloadConfig(server: server) }) {
                            HStack {
                                Text("重载配置文件")
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        
                        Button(action: { viewModel.updateGeoDatabase(server: server) }) {
                            HStack {
                                Text("更新 GEO 数据库")
                                Spacer()
                                Image(systemName: "globe.asia.australia")
                            }
                        }
                        
                        Button(action: { viewModel.clearFakeIP(server: server) }) {
                            HStack {
                                Text("清空 FakeIP 数据库")
                                Spacer()
                                Image(systemName: "trash")
                            }
                        }
                        
                        Button(action: {
                            // 显示重启确认对话框
                            showingRestartAlert = true
                        }) {
                            HStack {
                                Text("重启核心")
                                Spacer()
                                Image(systemName: "power")
                            }
                        }
                        
                        Button(action: {
                            // 显示更新确认对话框
                            showingUpgradeAlert = true
                        }) {
                            HStack {
                                Text("更新核心")
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        // hideKeyboard()
                    }
                }
            }
            .alert("重启核心", isPresented: $showingRestartAlert) {
                Button("取消", role: .cancel) { }
                Button("确认重启", role: .destructive) {
                    viewModel.restartCore(server: server)
                }
            } message: {
                Text("重启核心会导致服务暂时中断，确定要继续吗？")
            }
            .alert("更新核心", isPresented: $showingUpgradeAlert) {
                Button("取消", role: .cancel) { }
                Button("确认更新", role: .destructive) {
                    viewModel.upgradeCore(server: server)
                }
            } message: {
                Text("更新核心是一个高风险操作，可能会导致服务不可用。除非您明确知道自己在做什么，否则不建议执行此操作。\n\n确定要继续吗？")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchConfig(server: server)
            }
        }
    }
}

// 新增一个端口设置行的组件
struct PortSettingRow: View {
    let title: String
    @Binding var value: String
    let savedValue: String
    let configKey: String
    let onSubmit: (String) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: $value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .focused($isFocused)
                .onChange(of: isFocused) { focused in
                    if !focused {
                        if value != savedValue {
                            submitValue()
                        }
                    }
                }
        }
    }
    
    private func submitValue() {
        // 验证端口范围
        if let port = Int(value), (0...65535).contains(port) {
            onSubmit(value)
        } else {
            // 如果输入无效，恢复为保存的值
            value = savedValue
        }
    }
} 


enum ColorSchemeMode: String, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"
    
    func getColorScheme() -> ColorScheme? {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return nil
        }
    }
}


enum AppTintColor: String, CaseIterable {
    case monochrome, blue, brown, gray, green, indigo, mint, orange, pink, purple, red, teal, yellow
    
    func getColor() -> Color {
        switch self {
        case .monochrome:
            .primary
        case .blue:
            .blue
        case .red:
            .red
        case .green:
            .green
        case .yellow:
            .yellow
        case .brown:
            .brown
        case .gray:
            .gray
        case .indigo:
            .indigo
        case .mint:
            .mint
        case .orange:
            .orange
        case .pink:
            .pink
        case .purple:
            .purple
        case .teal:
            .teal
        }
    }
}

enum AppFontDesign: String, CaseIterable {
    case standard, monospaced, rounded, serif
    
    func getFontDesign() -> Font.Design {
        switch self {
        case .standard:
            .default
        case .monospaced:
            .monospaced
        case .rounded:
            .rounded
        case .serif:
            .serif
        }
    }
}

enum AppFontWidth: String, CaseIterable {
    case compressed, condensed, expanded, standard
    
    func getFontWidth() -> Font.Width {
        switch self {
        case .compressed:
            .compressed
        case .condensed:
            .condensed
        case .expanded:
            .expanded
        case .standard:
            .standard
        }
    }
}

enum AppFontSize: String, CaseIterable {
    case xsmall, small, medium, large, xlarge
    
    func getFontSize() -> DynamicTypeSize {
        switch self {
        case .xsmall:
            .xSmall
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        case .xlarge:
            .xLarge
        }
    }
}

struct AppearanceView: View {
    @ObservedObject private var appManager = AppManager.shared

    var body: some View {
        Form {
            
            Section {
                Picker(selection: $appManager.colorSchemeMode) {
                    ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                    }
                } label: {
                    Label("mode", systemImage: "moon")
                }
                Picker(selection: $appManager.appTintColor) {
                    ForEach(AppTintColor.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("color", systemImage: "paintbrush.pointed")
                }
            }

            Section(header: Text("font")) {
                Picker(selection: $appManager.appFontDesign) {
                    ForEach(AppFontDesign.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("design", systemImage: "textformat")
                }

                Picker(selection: $appManager.appFontWidth) {
                    ForEach(AppFontWidth.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("width", systemImage: "arrow.left.and.line.vertical.and.arrow.right")
                }
                .disabled(appManager.appFontDesign != .standard)

                #if !os(macOS)
                Picker(selection: $appManager.appFontSize) {
                    ForEach(AppFontSize.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { option in
                        Text(String(describing: option).lowercased())
                            .tag(option)
                    }
                } label: {
                    Label("size", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                #endif
            }
        }
        .formStyle(.grouped)
        .navigationBarTitle("Appearance", displayMode: .inline)
    }
}


struct AboutView: View {
    @StateObject var appManager = AppManager.shared
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "cloud.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .cornerRadius(12)
                        .foregroundColor(appManager.appTintColor.getColor())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appManager.appName)
                            .font(.headline)
                        Text("Version \(appManager.appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Additional Info Section
            Section(header: Text("About")) {
                Link(destination: URL(string: "https://github.com/lsongdev/cloudflare-ios")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("About")
        .listStyle(InsetGroupedListStyle())
    }
}
