import SwiftUI

// 添加到文件顶部，在 LoadingView 之前
struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }
}

struct ProxiesTab: View {
    
    @ObservedObject var appManager = AppManager.shared
    @State var groups: [ProxyDetail] = []
    @State var proxies: [ProxyDetail] = []
    @State var providers: [ProxyProvider] = []
    
    var server: ClashServer = AppManager.shared.currentServer
    
    var body: some View {
        List {
            Section("Proxy Groups") {
                ForEach(groups, id: \.name) { group in
                    ProxyGroupCard(group: group, proxies: proxies)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            
            Section("Proxy Providers") {
                ForEach(providers, id: \.name) { provider in
                    ProxyProviderCard(provider: provider)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .task {
            loadData()
        }
        .navigationTitle("Proxies")
        .navigationBarTitleDisplayMode(.inline)
    }
    func loadData() {
        Task {
            do {
                proxies = try await appManager.api.fetchProxies(server: server)
                providers = try await appManager.api.fetchProxyProviders(server: server)
                groups = proxies.compactMap { proxy in
                    guard proxy.isGroup else { return nil }
                    return proxy
                }
            } catch {
                print(error)
            }
        }
    }
}

struct ProxyProviderCard: View {
    @State private var updateStatus: UpdateStatus = .none
    
    let provider: ProxyProvider
    
    // 添加更新状态枚举
    private enum UpdateStatus {
        case none
        case updating
        case success
        case failure
    }
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var trafficInfo: (used: String, total: String, percentage: Double)? {
        guard let info = provider.subscriptionInfo else { return nil }
        let used = Double(info.upload + info.download)
        let total = Double(info.total)
        let percentage = total > 0 ? (used / total) * 100 : 100
        return (formatBytes(Int64(used)), formatBytes(info.total), percentage)
    }
    
    private var relativeUpdateTime: String {
        guard let updatedAt = provider.updatedAt else {
            print("Provider \(provider.name) updatedAt is nil")
            return "从未更新"
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: updatedAt) else {
            print("Failed to parse date: \(updatedAt)")
            return "未知"
        }
        
        let interval = Date().timeIntervalSince(date)
        
        switch interval {
        case 0..<60:
            return "刚刚"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        case 3600..<86400:
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        case 86400..<604800:
            let days = Int(interval / 86400)
            return "\(days) 天前"
        case 604800..<2592000:
            let weeks = Int(interval / 604800)
            return "\(weeks) 周前"
        default:
            let months = Int(interval / 2592000)
            return "\(months) 个月前"
        }
    }
    
    private var expirationDate: String? {
        guard let info = provider.subscriptionInfo else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(info.expire))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    var updateButton: some View {
        Button {
            
        } label: {
            Group {
                switch updateStatus {
                case .none:
                    Image(systemName: "arrow.clockwise")
                case .updating:
                    ProgressView()
                        .scaleEffect(0.7)
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .frame(width: 20, height: 20) // 固定大小避免图标切换时的跳动
        }
        .disabled(updateStatus != .none)
        .animation(.spring(), value: updateStatus)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(provider.name)
                            .font(.headline)
                        
                        Text(provider.vehicleType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    // 更新时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("更新时间：\(relativeUpdateTime)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 12) {
                    updateButton
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            // 到期时间
            if let expireDate = expirationDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("到期时间：\(expireDate)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            // 流量信息
            if let (used, total, percentage) = trafficInfo {
                VStack(alignment: .leading, spacing: 8) {
                    // 流量进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(getTrafficColor(percentage: percentage))
                                .frame(width: geometry.size.width * CGFloat(min(percentage, 100)) / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    // 流量详情
                    HStack {
                        Text("\(used) / \(total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                            .foregroundColor(getTrafficColor(percentage: percentage))
                    }
                }
            }
            
            ProxyNodeList(proxies: provider.proxies)
        }
        .padding()
        .cardShadow()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getTrafficColor(percentage: Double) -> Color {
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct ProxyNodeList: View {
    var proxies: [ProxyDetail]
    
    @State var expend: Bool = false
    
    private var delayStats: (green: Int, yellow: Int, red: Int, timeout: Int) {
        var green = 0   // 低延迟 (0-150ms)
        var yellow = 0  // 中等延迟 (151-300ms)
        var red = 0     // 高延迟 (>300ms)
        var timeout = 0 // 未连接 (0ms)
        
        for node in proxies {
            switch node.delay {
            case 0:
                timeout += 1
            case DelayColor.lowRange:
                green += 1
            case DelayColor.mediumRange:
                yellow += 1
            default:
                red += 1
            }
        }
        
        return (green, yellow, red, timeout)
    }
    
    var body: some View {
        VStack {
            // 使用新的延迟统计条
            DelayBar(
                green: delayStats.green,
                yellow: delayStats.yellow,
                red: delayStats.red,
                timeout: delayStats.timeout,
                total: proxies.count
            )
            .padding(.horizontal, 2)
            .onTapGesture {
                expend = !expend
            }
            
            if expend {
                ForEach(proxies, id: \.id) { node in
                    HStack {
                        Text(node.name)
                        Spacer()
                        if node.delay > 0 {
                            Text("\(node.delay) ms")
                                .foregroundStyle(DelayColor.color(for: node.delay))
                        } else {
                            Text("超时")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// 单个代理组卡片
struct ProxyGroupCard: View {
    
    @State private var showingProxySelector = false
    
    let group: ProxyDetail
    let proxies: [ProxyDetail]
    
    private var totalNodes: Int {
        group.all?.count ?? 0
    }
    
    
    private func getNodeIcon(for nodeName: String) -> String {
        switch nodeName {
        case "DIRECT":
            return "arrow.up.forward"
        case "REJECT":
            return "xmark.circle"
        default:
            if let node = proxies.first(where: { $0.name == nodeName }) {
                switch node.type.lowercased() {
                case "ss", "shadowsocks":
                    return "bolt.shield"
                case "vmess":
                    return "v.circle"
                case "trojan":
                    return "shield.lefthalf.filled"
                case "http", "https":
                    return "globe"
                case "socks", "socks5":
                    return "network"
                default:
                    return "antenna.radiowaves.left.and.right"
                }
            }
            return "antenna.radiowaves.left.and.right"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题行
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(group.name)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        

                    }
                    
                    
                }
                
                Spacer()
                
                Text(group.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                
            }
            
            Divider()
                .padding(.horizontal, -12)
            
            
            // 当前节点信息
            HStack(spacing: 6) {
                Image(systemName: getNodeIcon(for: group.now!))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                 if let currentNode = proxies.first(where: { $0.name == group.now }) {
                    Text(currentNode.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if currentNode.delay > 0 {
                        Text("\(currentNode.delay) ms")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DelayColor.color(for: currentNode.delay).opacity(0.1))
                            .foregroundStyle(DelayColor.color(for: currentNode.delay))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // 节点数量标签
                Text("\(totalNodes) 个节点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // TODO: xxxx
            ProxyNodeList(proxies: proxies)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .onTapGesture {
            // 添加触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 总是显示选择器
            showingProxySelector = true
        }
    }
    
    private func getStatusColor(for nodeName: String) -> Color {
        switch nodeName {
        case "DIRECT":
            return .green
        case "REJECT":
            return .red
        default:
            return .blue
        }
    }
    
}

struct ScrollClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

// 更新 DelayColor 构体，增加颜色饱和度
struct DelayColor {
    // 延迟范围常量
    static let lowRange = 0...150
    static let mediumRange = 151...300
    static let highThreshold = 300
    
    static func color(for delay: Int) -> Color {
        switch delay {
        case 0:
            return Color(red: 1.0, green: 0.2, blue: 0.2) // 更艳的红色
        case lowRange:
            return Color(red: 0.2, green: 0.8, blue: 0.2) // 鲜艳的绿色
        case mediumRange:
            return Color(red: 1.0, green: 0.75, blue: 0.0) // 明亮的黄色
        default:
            return Color(red: 1.0, green: 0.5, blue: 0.0) // 鲜艳的橙色
        }
    }
    
    static let disconnected = Color(red: 1.0, green: 0.2, blue: 0.2) // 更鲜艳的红色
    static let low = Color(red: 0.2, green: 0.8, blue: 0.2) // 鲜艳的绿色
    static let medium = Color(red: 1.0, green: 0.75, blue: 0.0) // 明亮的黄色
    static let high = Color(red: 1.0, green: 0.5, blue: 0.0) // 鲜艳的橙色
}

// 修改延迟测试动画组件
struct DelayTestingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .foregroundStyle(.blue)
            .onAppear {
                withAnimation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
            .onDisappear {
                isAnimating = false
            }
    }
}

//  GroupCard 中替换原来的延迟统计条部分
struct DelayBar: View {
    let green: Int
    let yellow: Int
    let red: Int
    let timeout: Int
    let total: Int
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                // 低延迟部分
                if green > 0 {
                    DelaySegment(
                        width: CGFloat(green) / CGFloat(total) * geometry.size.width,
                        color: DelayColor.low,
                        isFirst: true,
                        isLast: yellow == 0 && red == 0 && timeout == 0
                    )
                }
                
                // 中等延迟部分
                if yellow > 0 {
                    DelaySegment(
                        width: CGFloat(yellow) / CGFloat(total) * geometry.size.width,
                        color: DelayColor.medium,
                        isFirst: green == 0,
                        isLast: red == 0 && timeout == 0
                    )
                }
                
                // 高延迟部分
                if red > 0 {
                    DelaySegment(
                        width: CGFloat(red) / CGFloat(total) * geometry.size.width,
                        color: DelayColor.high,
                        isFirst: green == 0 && yellow == 0,
                        isLast: timeout == 0
                    )
                }
                
                // 超时部分
                if timeout > 0 {
                    DelaySegment(
                        width: CGFloat(timeout) / CGFloat(total) * geometry.size.width,
                        color: DelayColor.disconnected,
                        isFirst: green == 0 && yellow == 0 && red == 0,
                        isLast: true
                    )
                }
            }
        }
        .frame(height: 6)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray6))
        )
    }
}

// 延迟条段组件
struct DelaySegment: View {
    let width: CGFloat
    let color: Color
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        color
            .frame(width: max(width, 0))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .cornerRadius(isFirst ? 3 : 0, corners: .topLeft)
            .cornerRadius(isFirst ? 3 : 0, corners: .bottomLeft)
            .cornerRadius(isLast ? 3 : 0, corners: .topRight)
            .cornerRadius(isLast ? 3 : 0, corners: .bottomRight)
    }
}

// 添加圆角辅助扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
 
