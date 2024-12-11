import Foundation

// 将 VersionResponse 移到类外面
struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

@MainActor
class ServerViewModel: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate {
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private static let saveKey = "SavedClashServers"
    private var activeSessions: [URLSession] = []  // 保持 URLSession 的引用
    
    override init() {
        super.init()
        loadServers()
    }

    private func determineServerType(from response: VersionResponse) -> ClashServer.ServerType {
        if response.premium == true {
            return .premium
        } else if response.meta == true {
            return .meta
        }
        return .unknown
    }
    
    private func makeURLSession(for server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            if #available(iOS 15.0, *) {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            } else {
                config.tlsMinimumSupportedProtocolVersion = .TLSv12
            }
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        activeSessions.append(session)  // 保存 session 引用
        return session
    }
    
    private func makeRequest(for server: ClashServer, path: String) -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        var urlComponents = URLComponents()
        
        urlComponents.scheme = scheme
        urlComponents.host = server.url
        urlComponents.port = Int(server.port)
        urlComponents.path = path
        
        guard let url = urlComponents.url else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // print("🔐 收到证书验证请求")
        // print("认证方法: \(challenge.protectionSpace.authenticationMethod)")
        // print("主机: \(challenge.protectionSpace.host)")
        // print("端口: \(challenge.protectionSpace.port)")
        // print("协议: \(challenge.protectionSpace.protocol ?? "unknown")")
        
        // 始终接受所有证书
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // print("✅ 无条件接受服务器证书")
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                // print("⚠️ 无法获取服务器证书")
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            // print("❌ 默认处理证书验证")
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    @MainActor
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
    
    @MainActor
    private func checkServerStatus(_ server: ClashServer) async {
        guard let request = makeRequest(for: server, path: "/version") else {
            updateServerStatus(server, status: .error, message: "无效的请求")
            return
        }
        
        do {
            let session = makeURLSession(for: server)
            
            let (data, response) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.unknown))
                    }
                }
                task.resume()
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                updateServerStatus(server, status: .error, message: "无效的响应")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
                    var updatedServer = server
                    updatedServer.status = .ok
                    updatedServer.version = versionResponse.version
                    updatedServer.serverType = determineServerType(from: versionResponse)
                    updatedServer.errorMessage = nil
                    updateServer(updatedServer)
                } catch {
                    if let versionDict = try? JSONDecoder().decode([String: String].self, from: data),
                       let version = versionDict["version"] {
                        var updatedServer = server
                        updatedServer.status = .ok
                        updatedServer.version = version
                        updatedServer.errorMessage = nil
                        updateServer(updatedServer)
                    } else {
                        updateServerStatus(server, status: .error, message: "无效的响应格式")
                    }
                }
            case 401:
                updateServerStatus(server, status: .unauthorized, message: "认证失败，请检查密钥")
            case 404:
                updateServerStatus(server, status: .error, message: "API 路径不存在")
            case 500...599:
                updateServerStatus(server, status: .error, message: "服务器错误: \(httpResponse.statusCode)")
            default:
                updateServerStatus(server, status: .error, message: "未知响应: \(httpResponse.statusCode)")
            }
        } catch let urlError as URLError {
            print("🚫 URLError: \(urlError.localizedDescription)")
            
            switch urlError.code {
            case .cancelled:
                updateServerStatus(server, status: .error, message: "请求被取消")
            case .secureConnectionFailed:
                updateServerStatus(server, status: .error, message: "SSL/TLS 连接失败")
            case .serverCertificateUntrusted:
                updateServerStatus(server, status: .error, message: "证书不受信任")
            case .timedOut:
                updateServerStatus(server, status: .error, message: "连接超时")
            case .cannotConnectToHost:
                updateServerStatus(server, status: .error, message: "无法连接到服务器")
            case .notConnectedToInternet:
                updateServerStatus(server, status: .error, message: "网络未连接")
            default:
                updateServerStatus(server, status: .error, message: "网络错误")
            }
        } catch {
            print("❌ 未知错误: \(error)")
            updateServerStatus(server, status: .error, message: "未知错误")
        }
    }
    
    private func updateServerStatus(_ server: ClashServer, status: ServerStatus, message: String? = nil) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            var updatedServer = server
            updatedServer.status = status
            updatedServer.errorMessage = message
            servers[index] = updatedServer
            saveServers()
        }
    }
    
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode([ClashServer].self, from: data) {
            servers = decoded
        }
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }
    
    func addServer(_ server: ClashServer) {
        servers.append(server)
        saveServers()
        Task {
            await checkServerStatus(server)
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
            // Task {
            //     await checkServerStatus(server)
            // }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }
    
    func setQuickLaunch(_ server: ClashServer) {
        // 如果当前服务器已经是快速启动，则取消
        if server.isQuickLaunch {
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isQuickLaunch = false
            }
        } else {
            // 否则，先将所有服务器的 isQuickLaunch 设为 false
            for index in servers.indices {
                servers[index].isQuickLaunch = false
            }
            
            // 然后设置选中的服务器为快速启动
            if let index = servers.firstIndex(where: { $0.id == server.id }) {
                servers[index].isQuickLaunch = true
            }
        }
        
        // 保存更改
        saveServers()
    }
//    nonisolated func urlSession(
//        _ session: URLSession,
//        task: URLSessionTask,
//        willPerformHTTPRedirection response: HTTPURLResponse,
//        newRequest request: URLRequest,
//        completionHandler: @escaping (URLRequest?) -> Void
//    ) {
//        print("🔄 收到重定向请求")
//        print("从: \(task.originalRequest?.url?.absoluteString ?? "unknown")")
//        print("到: \(request.url?.absoluteString ?? "unknown")")
//        print("状态码: \(response.statusCode)")
//        completionHandler(nil)  // 不跟随重定向
//    }
} 
