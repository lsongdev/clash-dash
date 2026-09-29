import Foundation
import Combine
import SwiftUI  // 添加这行

class ConnectionsViewModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case paused
        case error(String)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.paused, .paused):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
        
        var message: String {
            switch self {
            case .disconnected:
                return "Not connected to a server"
            case .connecting:
                return "Connecting to server…"
            case .connected:
                return "Connected to server"
            case .paused:
                return "Monitoring paused"
            case .error(let message):
                return message
            }
        }
        
        var showStatus: Bool {
            return true
        }
        
        var statusColor: Color {
            switch self {
            case .connected:
                return .green
            case .connecting, .paused:
                return .blue
            case .disconnected, .error:
                return .red
            }
        }
        
        var statusIcon: String {
            switch self {
            case .connected:
                return "checkmark.circle.fill"
            case .connecting:
                return "arrow.clockwise"
            case .paused:
                return "pause.circle.fill"
            case .disconnected, .error:
                return "exclamationmark.triangle.fill"
            }
        }
        
        var isConnecting: Bool {
            if case .connecting = self {
                return true
            }
            return false
        }
    }
    
    @Published var connections: [ClashConnection] = []
    @Published var totalUpload: Int = 0
    @Published var totalDownload: Int = 0
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isMonitoring = false
    
    private var connectionsTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var server: ClashServer?
    
    private var previousConnections: [String: ClashConnection] = [:]
    private var reconnectTask: Task<Void, Never>?
    private var isReconnecting = false
    
    // 添加错误追踪
    private struct ErrorTracker {
        var count: Int = 0
        var firstErrorTime: Date?
        
        mutating func recordError() -> Bool {
            let now = Date()
            
            // 如果是第一个错误或者距离第一个错误超过5秒，重置计数
            if firstErrorTime == nil || now.timeIntervalSince(firstErrorTime!) > 5 {
                count = 1
                firstErrorTime = now
                return false
            }
            
            count += 1
            return count >= 3 // 返回是否达到阈值
        }
        
        mutating func reset() {
            count = 0
            firstErrorTime = nil
        }
    }
    
    private var errorTracker = ErrorTracker()
    
    private func log(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
    
    func startMonitoring(server: ClashServer) {
        self.server = server
        isMonitoring = true
        
        connectToConnections(server: server)
    }
    
    func stopMonitoring() {
        isMonitoring = false
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionsTask?.cancel()
        connectionsTask = nil
        errorTracker.reset()
        
        updateConnectionState(.paused)
    }
    
    private func connectToConnections(server: ClashServer) {
        guard isMonitoring else { return }
        
        // 取消之前的重连任务
        reconnectTask?.cancel()
        reconnectTask = nil
        
        // 构建 WebSocket URL，支持 SSL
        let scheme = server.useSSL ? "wss" : "ws"
        guard let url = URL(string: "\(scheme)://\(server.host):\(server.port)/connections") else {
            log("❌ URL 构建失败")
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .error("Could not build the server URL")
            }
            return
        }
        
        // 先测试 HTTP 连接
        let httpScheme = server.useSSL ? "https" : "http"
        var testRequest = URLRequest(url: URL(string: "\(httpScheme)://\(server.host):\(server.port)")!)
        if !server.secret.isEmpty {
            testRequest.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        
        // 如果使用 SSL，添加额外的配置
        let sessionConfig = URLSessionConfiguration.default
        if server.useSSL {
            sessionConfig.urlCache = nil // 禁用缓存
            sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            // 允许自签名证书
            sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
            sessionConfig.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        
        Task {
            do {
                let session = URLSession(configuration: sessionConfig)
                let (_, response) = try await session.data(for: testRequest)
                
                if let httpResponse = response as? HTTPURLResponse {
                    log("✅ HTTP 连接测试状态码: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 401 {
                        DispatchQueue.main.async { [weak self] in
                            self?.connectionState = .error("Authentication failed. Check the Secret.")
                        }
                        return
                    }
                }
                
                // 创建 WebSocket 请求
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                
                if !server.secret.isEmpty {
                    request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
                }
                
                // 取消现有连接
                connectionsTask?.cancel()
                connectionsTask = nil
                
                // 创建新连接
                let wsSession = URLSession(configuration: sessionConfig)
                let task = wsSession.webSocketTask(with: request)
                connectionsTask = task
                
                // 设置消息处理
                task.resume()
                receiveConnectionsData()
                
            } catch {
                log("❌ HTTP 连接测试失败: \(error.localizedDescription)")
                handleConnectionError(error)
            }
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        log("❌ 连接错误：\(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .error(error.localizedDescription)
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed:
                log("❌ SSL/TLS 连接失败")
                DispatchQueue.main.async { [weak self] in
                    self?.connectionState = .error("SSL/TLS connection failed. Check the certificate settings.")
                }
            case .serverCertificateUntrusted:
                log("❌ 服务器证书不受信任")
                DispatchQueue.main.async { [weak self] in
                    self?.connectionState = .error("The server certificate is not trusted")
                }
            case .clientCertificateRejected:
                log("❌ 客户端证书被拒绝")
                DispatchQueue.main.async { [weak self] in
                    self?.connectionState = .error("The client certificate was rejected")
                }
            default:
                break
            }
        }
    }
    
    private func receiveConnectionsData() {
        guard let task = connectionsTask, isMonitoring else { return }
        
        task.receive { [weak self] result in
            guard let self = self, self.isMonitoring else { return }
            
            switch result {
            case .success(let message):
                // 成功接收消息时重置错误计数
                self.errorTracker.reset()
                
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self.handleConnectionsMessage(data)
                    }
                case .data(let data):
                    self.handleConnectionsMessage(data)
                @unknown default:
                    break
                }
                
                // 继续接收下一条消息
                self.receiveConnectionsData()
                
            case .failure(let error):
                self.log("❌ WebSocket 错误：\(error.localizedDescription)")
                
                if errorTracker.recordError() {
                    DispatchQueue.main.async { [weak self] in
                        self?.connectionState = .error("Connection failed. Check the network or server.")
                    }
                    self.stopMonitoring()
                } else {
                    self.reconnect()
                }
            }
        }
    }
    
    private let maxHistoryCount = 200
    private var connectionHistory: [String: ClashConnection] = [:] // 用于存储历史记录
    
    private func updateConnectionState(_ newState: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 只有在以下情况才更新状态:
            // 1. 新状态是错误状态
            // 2. 当前不是错误状态
            // 3. 状态确实发生了变化
            if case .error = newState {
                self.connectionState = newState
            } else if case .error = self.connectionState {
                // 如果当前是错误状态，只有在明确要切换到其他状态时才更新
                if case .connecting = newState {
                    self.connectionState = newState
                }
            } else if self.connectionState != newState {
                self.connectionState = newState
            }
            
            // 记录状态变化
            log("状态更新: \(self.connectionState.message)")
        }
    }
    
    private func handleConnectionsMessage(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(ConnectionsResponse.self, from: data)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 更新连接状态
                self.updateConnectionState(.connected)
                
                // 更新总流量
                self.totalUpload = response.uploadTotal
                self.totalDownload = response.downloadTotal
                
                // 更新设备缓存，只添加新设备
                for connection in response.connections {
                    let ip = connection.metadata.sourceIP
                    if !self.deviceCache.contains(ip) {
                        self.deviceCache.append(ip)
                    }
                }
                
                // 如果连接数组为空，清空现有连接
                if response.connections.isEmpty {
                    self.connections = []
                    self.previousConnections = [:]
                    self.connectionHistory = [:]
                    return
                }
                
                var hasChanges = false
                let currentIds = Set(response.connections.map { $0.id })
                
                // 处理活跃连接
                for connection in response.connections {
                    let downloadSpeed = Double(
                        connection.download - (self.previousConnections[connection.id]?.download ?? connection.download)
                    )
                    let uploadSpeed = Double(
                        connection.upload - (self.previousConnections[connection.id]?.upload ?? connection.upload)
                    )
                    
                    // 创建更新后的连接对象
                    let updatedConnection = ClashConnection(
                        id: connection.id,
                        metadata: connection.metadata,
                        upload: connection.upload,
                        download: connection.download,
                        start: connection.start,
                        chains: connection.chains,
                        rule: connection.rule,
                        rulePayload: connection.rulePayload,
                        downloadSpeed: max(0, downloadSpeed),
                        uploadSpeed: max(0, uploadSpeed),
                        isAlive: true
                    )
                    
                    // 检查是否需要更新
                    if let existingConnection = self.connectionHistory[connection.id] {
                        if existingConnection != updatedConnection {
                            hasChanges = true
                            self.connectionHistory[connection.id] = updatedConnection
                        }
                    } else {
                        hasChanges = true
                        self.connectionHistory[connection.id] = updatedConnection
                    }
                }
                
                // 更新已断开连接的状态
                for (id, connection) in self.connectionHistory {
                    if !currentIds.contains(id) && connection.isAlive {
                        // 创建已断开的连接副本
                        let closedConnection = ClashConnection(
                            id: connection.id,
                            metadata: connection.metadata,
                            upload: connection.upload,
                            download: connection.download,
                            start: connection.start,
                            chains: connection.chains,
                            rule: connection.rule,
                            rulePayload: connection.rulePayload,
                            downloadSpeed: 0,
                            uploadSpeed: 0,
                            isAlive: false  // 标记为已断开
                        )
                        hasChanges = true
                        self.connectionHistory[id] = closedConnection
                    }
                }
                
                // 只在有变化时更新 UI
                if hasChanges {
                    // 转换为数组并按开始时间倒序排序
                    var sortedConnections = Array(self.connectionHistory.values)
                    sortedConnections.sort { conn1, conn2 in
                        // 只按时间排序，不考虑连接状态
                        return conn1.start > conn2.start
                    }
                    
                    self.connections = sortedConnections
                }
                
                // 更新上一次的连接数据，只保存活跃连接
                self.previousConnections = Dictionary(
                    uniqueKeysWithValues: response.connections.map { ($0.id, $0) }
                )
            }
        } catch DecodingError.valueNotFound(_, _) {
            // 处理空连接的情况
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.connections = []
                self.previousConnections = [:]
                self.connectionHistory = [:]
                self.updateConnectionState(.connected)  // 保持连接状态为已连接
            }
        } catch {
            log("❌ 解码错误：\(error)")
            self.updateConnectionState(.error("Could not parse data: \(error.localizedDescription)"))
        }
    }
    
    private func makeRequest(path: String, method: String = "GET") -> URLRequest? {
        let scheme = server?.useSSL == true ? "https" : "http"
        guard let server = server,
              let url = URL(string: "\(scheme)://\(server.host):\(server.port)/\(path)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 添加通用请求头
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        if server?.useSSL == true {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        return URLSession(configuration: config)
    }
    
    func closeConnection(_ id: String) {
        guard let request = makeRequest(path: "connections/\(id)", method: "DELETE") else { return }
        
        Task {
            do {
                let (_, response) = try await makeSession().data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 {
                    await MainActor.run {
                        if let index = connections.firstIndex(where: { $0.id == id }) {
                            var updatedConnection = connections[index]
                            connections[index] = ClashConnection(
                                id: updatedConnection.id,
                                metadata: updatedConnection.metadata,
                                upload: updatedConnection.upload,
                                download: updatedConnection.download,
                                start: updatedConnection.start,
                                chains: updatedConnection.chains,
                                rule: updatedConnection.rule,
                                rulePayload: updatedConnection.rulePayload,
                                downloadSpeed: 0,
                                uploadSpeed: 0,
                                isAlive: false
                            )
                        }
                    }
                }
            } catch {
                log("❌ 关闭连接失败: \(error.localizedDescription)")
            }
        }
    }
    
    func closeAllConnections() {
        guard let request = makeRequest(path: "connections", method: "DELETE") else { return }
        
        Task {
            do {
                let (_, response) = try await makeSession().data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 204 {
                    await MainActor.run {
                        // 清空所有连接相关的数据
                        connections.removeAll()
                        previousConnections.removeAll()
                    }
                }
            } catch {
                log("❌ 关闭所有连接失败: \(error.localizedDescription)")
            }
        }
    }
    
    func refresh() async {
        stopMonitoring()
        if let server = server {
            startMonitoring(server: server)
        }
    }
    
    private func reconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        
        // 取消现有的重连任务
        reconnectTask?.cancel()
        
        // 创建新的重连任务
        reconnectTask = Task {
            // 等待1秒后重试
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.updateConnectionState(.connecting)
                self.isReconnecting = false
                
                if let server = self.server {
                    self.connectToConnections(server: server)
                }
            }
        }
    }
    
    private func handleWebSocketError(_ error: Error) {
        log("❌ WebSocket 错误：\(error.localizedDescription)")
        
        if errorTracker.recordError() {
            DispatchQueue.main.async { [weak self] in
                if let urlError = error as? URLError, urlError.code == .secureConnectionFailed {
                    self?.connectionState = .error("SSL/TLS connection failed. Check the certificate settings.")
                } else {
                    self?.connectionState = .error("Connection failed. Check the network or server.")
                }
            }
            stopMonitoring()
        } else {
            reconnect()
        }
    }
    
    // 清理已关闭的连接
    func clearClosedConnections() {
        print("\n🧹 开始清理已断开连接")
        print("当前连接总数:", connections.count)
        print("历史连接数量:", previousConnections.count)
        
        // 获取要清理的连接ID
        let closedConnectionIds = connections.filter { !$0.isAlive }.map { $0.id }
        
        // 从当前连接列表中移除已断开的连接
        connections.removeAll { !$0.isAlive }
        
        // 从历史记录中也移除这些连接
        for id in closedConnectionIds {
            connectionHistory.removeValue(forKey: id)  // 修改这里：从 connectionHistory 中移除
            previousConnections.removeValue(forKey: id)  // 同时从 previousConnections 中移除
        }
        
        print("清理后连接数量:", connections.count)
        print("清理后历史连接数量:", previousConnections.count)
        print("✅ 清理完成")
        print("-------------------\n")
    }
    
    private func handleConnectionsUpdate(_ response: ConnectionsResponse) {
        Task { @MainActor in
            totalUpload = response.uploadTotal
            totalDownload = response.downloadTotal
            
            var updatedConnections: [ClashConnection] = []
            
            for connection in response.connections {
                if let previousConnection = previousConnections[connection.id] {
                    // 只有活跃的连接才会被添加到更新列表中
                    if connection.isAlive {
                        let updatedConnection = ClashConnection(
                            id: connection.id,
                            metadata: connection.metadata,
                            upload: connection.upload,
                            download: connection.download,
                            start: connection.start,
                            chains: connection.chains,
                            rule: connection.rule,
                            rulePayload: connection.rulePayload,
                            downloadSpeed: Double(connection.download - previousConnection.download),
                            uploadSpeed: Double(connection.upload - previousConnection.upload),
                            isAlive: connection.isAlive
                        )
                        updatedConnections.append(updatedConnection)
                    }
                } else if connection.isAlive {
                    // 新的活跃连接
                    let newConnection = ClashConnection(
                        id: connection.id,
                        metadata: connection.metadata,
                        upload: connection.upload,
                        download: connection.download,
                        start: connection.start,
                        chains: connection.chains,
                        rule: connection.rule,
                        rulePayload: connection.rulePayload,
                        downloadSpeed: 0,
                        uploadSpeed: 0,
                        isAlive: connection.isAlive
                    )
                    updatedConnections.append(newConnection)
                }
                
                // 只保存活跃连接的历史记录
                if connection.isAlive {
                    previousConnections[connection.id] = connection
                }
            }
            
            connections = updatedConnections
        }
    }
    
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else if let server = server {
            startMonitoring(server: server)
        }
    }
    
    // 修改设备缓存为有序数组，以保持设备顺序
    private(set) var deviceCache: [String] = []  // 存储所有出现过的设备IP，按出现顺序排列
}
