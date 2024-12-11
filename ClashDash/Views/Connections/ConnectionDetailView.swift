import SwiftUI

struct ConnectionDetailView: View {
    private let initialConnection: ClashConnection
    @ObservedObject var viewModel: ConnectionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCopyMenu = false
    @State private var selectedValue: String = ""
    @State private var connectionLostTimer: Timer?
    @State private var isConnectionLost = false
    @State private var currentConnection: ClashConnection
    @State private var durationTimer: Timer?
    @State private var currentDuration: String = ""
    @State private var showIPInfo = false
    @State private var ipInfoURL: URL?
    
    init(connection: ClashConnection, viewModel: ConnectionsViewModel) {
        self.initialConnection = connection
        self.viewModel = viewModel
        self._currentConnection = State(initialValue: connection)
        self._currentDuration = State(initialValue: Self.formatDuration(from: connection.start))
    }
    
    private static func formatDuration(from startDate: Date) -> String {
        let endDate = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate, to: endDate)
        var parts: [String] = []
        
        if let years = components.year, years > 0 {
            parts.append("\(years)y")
        }
        if let months = components.month, months > 0 {
            parts.append("\(months)m")
        }
        if let days = components.day, days > 0 {
            parts.append("\(days)d")
        }
        if let hours = components.hour, hours > 0 {
            parts.append("\(hours)h")
        }
        if let minutes = components.minute, minutes > 0 {
            parts.append("\(minutes)m")
        }
        if let seconds = components.second {
            parts.append("\(seconds)s")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func startDurationTimer() {
        // 先停止现有的计时器
        durationTimer?.invalidate()
        durationTimer = nil
        
        // 如果连接已断开，只显示最终时长
        if !currentConnection.isAlive {
            currentDuration = Self.formatDuration(from: currentConnection.start)
            return
        }
        
        // 只有活跃的连接才启动计时器
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentDuration = Self.formatDuration(from: currentConnection.start)
        }
        RunLoop.current.add(durationTimer!, forMode: .common)
    }
    
    private func startConnectionLostTimer() {
        guard connectionLostTimer == nil else { return }
        
        connectionLostTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            isConnectionLost = true
            connectionLostTimer = nil
            // 停止时长计时器并立即更新最终时长
            durationTimer?.invalidate()
            durationTimer = nil
            // 更新连接状态为断开
            currentConnection = ClashConnection(
                id: currentConnection.id,
                metadata: currentConnection.metadata,
                upload: currentConnection.upload,
                download: currentConnection.download,
                start: currentConnection.start,
                chains: currentConnection.chains,
                rule: currentConnection.rule,
                rulePayload: currentConnection.rulePayload,
                downloadSpeed: 0,
                uploadSpeed: 0,
                isAlive: false,
                endTime: Date()
            )
            // 更新一次最终时长
            currentDuration = Self.formatDuration(from: currentConnection.start)
        }
    }
    
    private func cleanup() {
        connectionLostTimer?.invalidate()
        connectionLostTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func updateConnectionStatus() {
        if let newConnection = viewModel.connections.first(where: { $0.id == initialConnection.id }) {
            // 找到连接，更新状态
            connectionLostTimer?.invalidate()
            connectionLostTimer = nil
            isConnectionLost = false
            currentConnection = newConnection
        } else if !isConnectionLost {
            startConnectionLostTimer()
        }
    }
    
    // 添加触觉反馈生成器
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // 格式化时间的辅助方法
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 格式化流量的辅助方法
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // 格式化速度的辅助方法
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = bytesPerSecond
        var unitIndex = 0
        
        while speed >= 1024 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        if speed < 0.1 {
            return "0 \(units[unitIndex])"
        }
        
        if speed >= 100 {
            return String(format: "%.0f %@", min(speed, 999), units[unitIndex])
        } else if speed >= 10 {
            return String(format: "%.1f %@", speed, units[unitIndex])
        } else {
            return String(format: "%.2f %@", speed, units[unitIndex])
        }
    }
    
    // 创建详情行组件
    @ViewBuilder
    private func DetailRow(title: String, value: String?, copyable: Bool = true) -> some View {
        if let value = value, !value.isEmpty {
            HStack {
                Text(title)
                    .foregroundColor(.secondary)
                Spacer()
                if title == "目标地址" {
                    Text(value)
                        .foregroundColor(.primary)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = value
                                impactFeedback.impactOccurred()
                            }) {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            
                            Button(action: {
                                if let url = URL(string: "https://ipinfo.io/\(value)") {
                                    showIPInfo = true
                                    ipInfoURL = url
                                }
                            }) {
                                Label("查看 IP 信息", systemImage: "info.circle")
                            }
                        }
                } else if copyable {
                    Text(value)
                        .foregroundColor(.primary)
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = value
                                impactFeedback.impactOccurred()
                            }) {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                        }
                } else {
                    Text(value)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private func StatusBadge(isAlive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isAlive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isAlive ? "活跃中" : "已断开")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(isAlive ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isAlive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
    
    // 处理 GeoIP 数组的辅助方法
    private func formatGeoIP(_ geoip: [String]?) -> String? {
        guard let geoip = geoip else { return nil }
        let nonEmptyLocations = geoip.filter { !$0.isEmpty }
        return nonEmptyLocations.isEmpty ? nil : nonEmptyLocations.joined(separator: ", ")
    }
    
    // 处理单个 GeoIP 的辅助方法
    private func formatSingleGeoIP(_ geoip: String?) -> String? {
        guard let geoip = geoip, !geoip.isEmpty else { return nil }
        return geoip
    }
    
    private var breakButton: some View {
        Button {
            Task {
                await viewModel.closeConnection(currentConnection.id)
            }
        } label: {
            Text("打断")
                .foregroundColor(currentConnection.isAlive ? .red : .gray)
        }
        .disabled(!currentConnection.isAlive)
    }
    
    var body: some View {
        List {
            // 状态信息
            Section {
                HStack {
                    Text("连接状态")
                        .foregroundColor(.secondary)
                    Spacer()
                    StatusBadge(isAlive: currentConnection.isAlive)
                }
                
                DetailRow(title: "开始时间", value: formatDate(currentConnection.start))
                DetailRow(title: "连接时长", value: currentConnection.isAlive ? currentDuration : currentConnection.formattedDuration)
                
            } header: {
                Text("基本信息")
            }
            
            // 目标信息
            Section {
                DetailRow(title: "主机名", value: currentConnection.metadata.host)
                DetailRow(title: "目标地址", value: currentConnection.metadata.destinationIP)
                DetailRow(title: "目标端口", value: currentConnection.metadata.destinationPort)
                DetailRow(title: "目标地理位置", value: formatGeoIP(currentConnection.metadata.destinationGeoIP))
                DetailRow(title: "目标ASN", value: currentConnection.metadata.destinationIPASN)
            } header: {
                Text("目标信息")
            }
            
            // 来源信息
            Section {
                DetailRow(title: "来源地址", value: currentConnection.metadata.sourceIP)
                DetailRow(title: "来源端口", value: currentConnection.metadata.sourcePort)
                DetailRow(title: "来源地理位置", value: formatSingleGeoIP(currentConnection.metadata.sourceGeoIP))
                DetailRow(title: "来源ASN", value: currentConnection.metadata.sourceIPASN)
            } header: {
                Text("来源信息")
            }

            // 流量信息
            Section {
                DetailRow(title: "上传流量", value: formatBytes(currentConnection.upload))
                DetailRow(title: "下载流量", value: formatBytes(currentConnection.download))
                DetailRow(title: "上传速度", value: formatSpeed(currentConnection.uploadSpeed))
                DetailRow(title: "下载速度", value: formatSpeed(currentConnection.downloadSpeed))
            } header: {
                Text("流量统计")
            }
            
            // 规则信息
            Section {
                DetailRow(title: "规则类型", value: currentConnection.rule)
                DetailRow(title: "规则内容", value: currentConnection.rulePayload)
                DetailRow(title: "代理链", value: currentConnection.chains.isEmpty ? "N/A" : currentConnection.chains.joined(separator: " → "))
            } header: {
                Text("规则信息")
            }
            
            // 入站信息
            Section {
                DetailRow(title: "入站类型", value: currentConnection.metadata.type)
                DetailRow(title: "入站地址", value: currentConnection.metadata.inboundIP)
                DetailRow(title: "入站端口", value: currentConnection.metadata.inboundPort)
                DetailRow(title: "入站名称", value: currentConnection.metadata.inboundName)
                DetailRow(title: "入站用户", value: currentConnection.metadata.inboundUser)
            } header: {
                Text("入站信息")
            }
            
            
            
            // 其他信息
            Section {
                DetailRow(title: "连接ID", value: currentConnection.id)
                DetailRow(title: "网络类型", value: currentConnection.metadata.network.uppercased())
                DetailRow(title: "DNS模式", value: currentConnection.metadata.dnsMode)
                DetailRow(title: "进程名", value: currentConnection.metadata.process)
                DetailRow(title: "进程路径", value: currentConnection.metadata.processPath)
                DetailRow(title: "UID", value: currentConnection.metadata.uid.map(String.init) ?? "0")
                DetailRow(title: "DSCP", value: currentConnection.metadata.dscp.map(String.init) ?? "0")
            } header: {
                Text("其他信息")
            }
        }
        .navigationTitle("连接详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("关闭") {
                    cleanup()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                breakButton
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            // 视图首次出现时，根据初始状态决定是否启动计时器
            if !currentConnection.isAlive {
                currentDuration = Self.formatDuration(from: currentConnection.start)
            } else {
                startDurationTimer()
            }
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: viewModel.connections) { _ in
            updateConnectionStatus()
        }
        .onChange(of: currentConnection) { newConnection in
            // 根据连接状态控制计时器
            if !newConnection.isAlive {
                durationTimer?.invalidate()
                durationTimer = nil
                currentDuration = Self.formatDuration(from: newConnection.start)
            } else {
                startDurationTimer()
            }
        }
        .sheet(isPresented: $showIPInfo) {
            if let url = ipInfoURL {
                SafariWebView(url: url)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionDetailView(
            connection: .preview(),
            viewModel: ConnectionsViewModel()
        )
    }
}
