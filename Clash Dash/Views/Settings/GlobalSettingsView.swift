import SwiftUI
import CoreHaptics

struct GlobalSettingsView: View {
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("proxyGroupSortOrder") private var proxyGroupSortOrder = ProxyGroupSortOrder.default
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    
    var body: some View {
        Form {
            Section {
                SettingToggleRow(
                    title: "自动断开旧连接",
                    subtitle: "切换代理时自动断开旧的连接",
                    isOn: $autoDisconnectOldProxy
                )
            } header: {
                SectionHeader(title: "切换代理设置", systemImage: "network")
            }
            
            Section {
                SettingToggleRow(
                    title: "隐藏不可用代理",
                    subtitle: "在列表中不显示无法连接的代理",
                    isOn: $hideUnavailableProxies
                )
                
                NavigationLink {
                    ProxyGroupSortOrderView(selection: $proxyGroupSortOrder)
                } label: {
                    SettingRow(
                        title: "排序方式",
                        value: proxyGroupSortOrder.description
                    )
                }
                
                InfoRow(message: "DIRECT（直连）和 REJECT（拒绝）节点会始终显示在列表中")
            } header: {
                SectionHeader(title: "排序设置", systemImage: "arrow.up.arrow.down")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                        TextField("测速链接", text: $speedTestURL)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Text("用于测试代理延迟的URL地址")
                        .caption()
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("超时时间")
                        Spacer()
                        Text("\(speedTestTimeout) ms")
                            .monospacedDigit()
                        Stepper("", value: $speedTestTimeout, in: 1000...10000, step: 500)
                            .labelsHidden()
                            .frame(width: 100)
                            .onChange(of: speedTestTimeout) { _ in
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    }
                    
                    Text("测速请求的最大等待时间")
                        .caption()
                }
            } header: {
                SectionHeader(title: "测速设置", systemImage: "speedometer")
            }
        }
        .navigationTitle("全局配置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 辅助视图组件
struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .caption()
            }
        }
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let message: String
    
    var body: some View {
        Label {
            Text(message)
                .caption()
        } icon: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(.secondary)
            .textCase(nil)
    }
}

// 扩展便捷修饰符
extension View {
    func caption() -> some View {
        self.font(.caption)
            .foregroundColor(.secondary)
    }
}

// 单独的排序设置视图
struct ProxyGroupSortOrderView: View {
    @Binding var selection: ProxyGroupSortOrder
    
    var body: some View {
        List {
            ForEach(ProxyGroupSortOrder.allCases) { order in
                Button {
                    selection = order
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack {
                        Text(order.description)
                        Spacer()
                        if order == selection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("排序方式")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ProxyGroupSortOrder: String, CaseIterable, Identifiable {
    case `default` = "default"
    case latencyAsc = "latencyAsc"
    case latencyDesc = "latencyDesc"
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .default: return "原 config 文件中的排序"
        case .latencyAsc: return "按延迟从小到大"
        case .latencyDesc: return "按延迟从大到小"
        case .nameAsc: return "按名称字母排序 (A-Z)"
        case .nameDesc: return "按名称字母排序 (Z-A)"
        }
    }
}

#Preview {
    NavigationStack {
        GlobalSettingsView()
    }
} 