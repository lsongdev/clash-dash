import SwiftUI

struct ConnectionsView: View {
    let server: ClashServer
    @StateObject private var viewModel = ConnectionsViewModel()
    @StateObject private var tagViewModel = ClientTagViewModel()
    @State private var searchText = ""
    @State private var selectedProtocols: Set<String> = ["TCP", "UDP"]
    @State private var connectionFilter: ConnectionFilter = .active
    @State private var showMenu = false
    @State private var showClientTagSheet = false
    @State private var selectedConnection: ClashConnection?
    
    // 添加确认对话框的状态
    @State private var showCloseAllConfirmation = false
    @State private var showClearClosedConfirmation = false
    
    // 添加枚举类型
    private enum ConnectionFilter {
        case active   // 正活跃
        case closed   // 已断开
        
        var title: String {
            switch self {
            case .active: return "正活跃"
            case .closed: return "已断开"
            }
        }
    }
    
    // 添加排序类型枚举
    private enum SortOption: String, CaseIterable {
        case startTime = "开始时间"
        case download = "下载流量"
        case upload = "上传流量"
        case downloadSpeed = "下载速度"
        case uploadSpeed = "上传速度"
        
        var icon: String {
            switch self {
            case .startTime: return "clock"
            case .download: return "arrow.down.circle"
            case .upload: return "arrow.up.circle"
            case .downloadSpeed: return "arrow.down.circle.fill"
            case .uploadSpeed: return "arrow.up.circle.fill"
            }
        }
    }
    
    @State private var selectedSortOption: SortOption = .startTime
    @State private var isAscending = false
    
    // 添加计算属性来获取不同类型的连接数量
    private var activeConnectionsCount: Int {
        viewModel.connections.filter { $0.isAlive }.count
    }
    
    private var closedConnectionsCount: Int {
        viewModel.connections.filter { !$0.isAlive }.count
    }
    
    private var tcpConnectionsCount: Int {
        viewModel.connections.filter { connection in
            let isMatchingState = connectionFilter == .active ? connection.isAlive : !connection.isAlive
            return isMatchingState && connection.metadata.network.uppercased() == "TCP"
        }.count
    }
    
    private var udpConnectionsCount: Int {
        viewModel.connections.filter { connection in
            let isMatchingState = connectionFilter == .active ? connection.isAlive : !connection.isAlive
            return isMatchingState && connection.metadata.network.uppercased() == "UDP"
        }.count
    }
    
    // 添加控制搜索栏显示的状态
    @State private var showSearch = false
    
    // 在 struct ConnectionsView 的开头添加状态变量
    @State private var showDeviceFilter = false
    @State private var selectedDevices: Set<String> = []  // 存储选中的设备ID（IP或设备名称）
    
    // 在 SortOption 枚举前添加 DeviceFilterButton
    private var deviceFilterButton: some View {
        Menu {
            let devices = getActiveDevices()
            if devices.isEmpty {
                Text("暂无设备记录")
            } else {
                Button("显示全部") {
                    selectedDevices.removeAll()
                }
                
                Button("全部隐藏") {
                    selectedDevices = Set(devices.map(\.id))
                }
                Divider()
                ForEach(viewModel.deviceCache, id: \.self) { ip in
                    if let device = devices.first(where: { $0.id == ip }) {
                        Button {
                            if selectedDevices.contains(device.id) {
                                selectedDevices.remove(device.id)
                            } else {
                                selectedDevices.insert(device.id)
                            }
                        } label: {
                            HStack {
                                Text(device.displayName)
                                    .foregroundColor(device.activeCount > 0 ? .primary : .secondary)
                                
                                if !selectedDevices.contains(device.id) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                
                
                
            }
        } label: {
            Image(systemName: "desktopcomputer")
                .foregroundColor(selectedDevices.isEmpty ? .accentColor : .gray)
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
        }
    }
    
    // 添加一个设备模型来存储设备信息
    private struct Device: Identifiable, Hashable {
        let id: String      // IP 地址
        let name: String?   // 设备标签名称（如果有）
        let activeCount: Int  // 活跃连接数
        
        var displayName: String {
            let baseName = name ?? id
            return "\(baseName) (\(activeCount))"
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Device, rhs: Device) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // 修改获取设备的方法
    private func getActiveDevices() -> Set<Device> {
        return Set(viewModel.deviceCache.map { ip in
            let activeCount = viewModel.connections.filter {
                $0.isAlive && $0.metadata.sourceIP == ip
            }.count
            
            return Device(
                id: ip,
                name: tagViewModel.tags.first(where: { $0.ip == ip })?.name,
                activeCount: activeCount
            )
        })
    }
    
    // 修改过滤连接的计算属性
    private var filteredConnections: [ClashConnection] {
        var connections = viewModel.connections.filter { connection in
            // 反转设备过滤条件：如果设备在选中列表中,则不显示
            let deviceMatches = !selectedDevices.contains(connection.metadata.sourceIP)
            
            // 根据连接状态过滤
            let stateMatches = connectionFilter == .active ? connection.isAlive : !connection.isAlive
            
            // 添加搜索过滤逻辑
            let searchMatches = searchText.isEmpty || {
                let searchTerm = searchText.lowercased()
                let metadata = connection.metadata
                
                // 检查源 IP 和端口
                if "\(metadata.sourceIP):\(metadata.sourcePort)".lowercased().contains(searchTerm) {
                    return true
                }
                
                // 检查主机名
                if metadata.host.lowercased().contains(searchTerm) {
                    return true
                }
                
                // 检查设备标签（如果有的话）
                if let deviceName = tagViewModel.tags.first(where: { $0.ip == metadata.sourceIP })?.name,
                   deviceName.lowercased().contains(searchTerm) {
                    return true
                }
                
                return false
            }()
            
            return deviceMatches && stateMatches && searchMatches
        }
        
        // 修改排序逻辑
        connections.sort { conn1, conn2 in
            switch selectedSortOption {
            case .startTime:
                return conn1.start.compare(conn2.start) == (isAscending ? .orderedAscending : .orderedDescending)
            case .download:
                return isAscending ? conn1.download < conn2.download : conn1.download > conn2.download
            case .upload:
                return isAscending ? conn1.upload < conn2.upload : conn1.upload > conn2.upload
            case .downloadSpeed:
                return isAscending ? conn1.downloadSpeed < conn2.downloadSpeed : conn1.downloadSpeed > conn2.downloadSpeed
            case .uploadSpeed:
                return isAscending ? conn1.uploadSpeed < conn2.uploadSpeed : conn1.uploadSpeed > conn2.uploadSpeed
            }
        }
        
        return connections
    }
    
    // 修改菜单按钮部分
    var menuButtons: some View {
        VStack(spacing: 12) {
            if showMenu {
                // 搜索按钮 - 添加到菜单的最上方
                MenuButton(
                    icon: "magnifyingglass",
                    color: showSearch ? .green : .gray,
                    action: {
                        withAnimation {
                            showSearch.toggle()
                            if !showSearch {
                                // 隐藏搜索栏时清空搜索内容
                                searchText = ""
                            }
                        }
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 暂停/继续监控
                MenuButton(
                    icon: viewModel.isMonitoring ? "pause.fill" : "play.fill",
                    color: .accentColor,
                    action: {
                        viewModel.toggleMonitoring()
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 客户端标签
                MenuButton(
                    icon: "tag.fill",
                    color: .blue,
                    action: {
                        showClientTagSheet = true
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 刷新视图
                MenuButton(
                    icon: "arrow.clockwise",
                    color: .green,
                    action: {
                        Task {
                            await viewModel.refresh()
                        }
                        showMenu = false
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 清理已断开连接
                MenuButton(
                    icon: "trash.fill",
                    color: .orange,
                    action: {
                        showClearClosedConfirmation = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                // 终止所有连接
                MenuButton(
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: {
                        showCloseAllConfirmation = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 修改主按钮的旋转角度
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showMenu.toggle()
                }
            }) {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(showMenu ? 90 : 0))
                            .foregroundColor(.accentColor)
                            .font(.system(size: 24, weight: .semibold))
                    }
            }
        }
        .alert("确定清理已断开连接", isPresented: $showClearClosedConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                viewModel.clearClosedConnections()
                showMenu = false
            }
        } message: {
            Text("确定要清除所有已断开的连接吗？\n这将从列表中移除 \(closedConnectionsCount) 个已断开的连接。")
        }
        .alert("确认终止所有连接", isPresented: $showCloseAllConfirmation) {
            Button("取消", role: .cancel) { }
            Button("终止", role: .destructive) {
                viewModel.closeAllConnections()
                showMenu = false
            }
        } message: {
            Text("确定要终止所有活跃的连接吗？\n这将断开 \(activeConnectionsCount) 个正在活跃的连接。")
        }
    }
    
    // 修改过滤标签组件
    struct FilterTag: View {
        let title: String
        let count: Int
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(title)
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .medium))
                    Text("(\(count))")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(height: 28)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.15))
                )
                .opacity(isSelected ? 1.0 : 0.6)
            }
            .buttonStyle(.plain)
        }
    }
    
    // 修改过滤标签栏
    var filterBar: some View {
        HStack(spacing: 6) {
            // 连接状态切换器
            Picker("连接状态", selection: $connectionFilter) {
                Text("正活跃 (\(activeConnectionsCount))")
                    .tag(ConnectionFilter.active)
                Text("已断开 (\(closedConnectionsCount))")
                    .tag(ConnectionFilter.closed)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 0)
            
            // 添加设备过滤按钮
            deviceFilterButton
            
            // 排序按钮
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        if selectedSortOption == option {
                            isAscending.toggle()
                        } else {
                            selectedSortOption = option
                            isAscending = false
                        }
                    } label: {
                        HStack {
                            Label(option.rawValue, systemImage: option.icon)
                            if selectedSortOption == option {
                                Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
    
    private func EmptyStateView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暂无连接")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("当前没有活跃的网络连接")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                
                // 过滤标签栏
                filterBar
                
                // 搜索栏 - 有条件地显示
                if showSearch {
                    SearchBar(text: $searchText, placeholder: "搜索 IP、端口、主机名、设备标签")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if viewModel.connections.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConnections) { connection in
                                ConnectionRow(
                                    connection: connection,
                                    viewModel: viewModel,
                                    tagViewModel: tagViewModel,
                                    onClose: {
                                        // 添加触觉反馈
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                        viewModel.closeConnection(connection.id)
                                    },
                                    selectedConnection: $selectedConnection
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.vertical, 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: filteredConnections)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            
            // 连接状态栏
            HStack {
                // 状态信息
                Image(systemName: viewModel.connectionState.statusIcon)
                    .foregroundColor(viewModel.connectionState.statusColor)
                    .rotationEffect(viewModel.connectionState.isConnecting ? .degrees(360) : .degrees(0))
                    .animation(viewModel.connectionState.isConnecting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.connectionState)
                
                Text(viewModel.connectionState.message)
                    .font(.footnote)
                
                if viewModel.connectionState.isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
                
                // 流量统计
                HStack(spacing: 12) {
                    Label(viewModel.formatBytes(viewModel.totalDownload), systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Label(viewModel.formatBytes(viewModel.totalUpload), systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                }
                .font(.footnote)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(viewModel.connectionState.statusColor.opacity(0.1))
            
            menuButtons
                .padding()
        }
        .sheet(item: $selectedConnection) { connection in
            NavigationStack {
                ConnectionDetailView(
                    connection: connection,
                    viewModel: viewModel
                )
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
        .onAppear {
            viewModel.startMonitoring(server: server)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .sheet(isPresented: $showClientTagSheet) {
            ClientTagView(
                viewModel: viewModel,
                tagViewModel: tagViewModel
            )
        }
    }
}

// 菜单按钮组件
struct MenuButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 40, height: 40)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .overlay {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14, weight: .semibold))
                }
        }
    }
}

// 添加自定义搜索栏组件
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        ConnectionsView(
            server: ClashServer(
                name: "测试服务器",
                url: "10.1.1.2",
                port: "9090",
                secret: "123456"
            )
        )
    }
}
