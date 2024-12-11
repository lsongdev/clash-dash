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
    
    // 修改验证方法
    func validateOpenWRTServer(_ server: ClashServer, username: String, password: String) async throws -> OpenWRTStatus {
        let scheme = server.useSSL ? "https" : "http"
        let baseURL = "\(scheme)://\(server.url):\(server.openWRTPort ?? "80")"
        print("🔍 开始验证 OpenWRT 服务器: \(baseURL)")
        
        // 1. 尝试登录
        guard let loginURL = URL(string: "\(baseURL)/cgi-bin/luci/") else {
            print("❌ 登录 URL 无效")
            throw NetworkError.invalidURL
        }
        
        // 创建一个新的 URLSession 配置
        let config = URLSessionConfiguration.ephemeral  // 使用 ephemeral 配置，不保存任何缓存和 cookie
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpMaximumConnectionsPerHost = 1
        
        // 使用新的配置创建 session，并确保设置了 delegate
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        activeSessions.append(session)
        
        do {
            // 创建登录请求
            var loginRequest = URLRequest(url: loginURL)
            loginRequest.httpMethod = "POST"

            // 复制所有头部
            loginRequest.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7", forHTTPHeaderField: "Accept")
            loginRequest.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh-TW;q=0.7,zh;q=0.6", forHTTPHeaderField: "Accept-Language")
            loginRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            loginRequest.setValue("keep-alive", forHTTPHeaderField: "Connection")
            loginRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            loginRequest.setValue("1", forHTTPHeaderField: "DNT")
            let originURL = "\(scheme)://\(server.url)"
            loginRequest.setValue(originURL, forHTTPHeaderField: "Origin")
            loginRequest.setValue("no-cache", forHTTPHeaderField: "Pragma")
            loginRequest.setValue("\(originURL)/cgi-bin/luci/", forHTTPHeaderField: "Referer")
            loginRequest.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
            loginRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

            // 使用 data-raw 格式的请求体
            let loginBody = "luci_username=\(username)&luci_password=\(password)"
            loginRequest.httpBody = loginBody.data(using: .utf8)
            
            print("📤 发送登录请求")
            print("📝 请求头: \(loginRequest.allHTTPHeaderFields ?? [:])")
            print("📝 请求体: \(loginBody)")
            
            let (loginData, loginResponse) = try await session.data(for: loginRequest)
            
            guard let httpResponse = loginResponse as? HTTPURLResponse else {
                print("❌ 无效的响应类型")
                throw NetworkError.invalidResponse
            }
            
            print("📥 登录响应状态码: \(httpResponse.statusCode)")
            print("📥 登录响应头: \(httpResponse.allHeaderFields)")
            if let responseStr = String(data: loginData, encoding: .utf8) {
                print("📥 登录响应体: \(responseStr)")
            }
            
            // 检查状态码和 set-cookie 头
            guard httpResponse.statusCode == 302,
                  let cookies = httpResponse.value(forHTTPHeaderField: "set-cookie"),
                  let sysauth = cookies.split(separator: ";").first else {
                print("❌ 登录失败：状态码 \(httpResponse.statusCode)")
                throw NetworkError.unauthorized
            }
            
            print("🍪 获取到 Cookie: \(sysauth)")
            
            // 2. 使用 cookie 获取 OpenClash 状态
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            guard let statusURL = URL(string: "\(baseURL)/cgi-bin/luci/admin/services/openclash/status?\(timestamp)") else {
                print("❌ 状态 URL 无效")
                throw NetworkError.invalidURL
            }
            
            print("📤 发送状态请求: \(statusURL)")
            var statusRequest = URLRequest(url: statusURL)
            statusRequest.setValue(String(sysauth), forHTTPHeaderField: "Cookie")
            
            let (statusData, statusResponse) = try await session.data(for: statusRequest)
            
            guard let statusHttpResponse = statusResponse as? HTTPURLResponse else {
                print("❌ 无效的状态响应类型")
                throw NetworkError.invalidResponse
            }
            
            print("📥 状态响应状态码: \(statusHttpResponse.statusCode)")
            if let responseStr = String(data: statusData, encoding: .utf8) {
                print("📥 状态响应体: \(responseStr)")
            }
            
            switch statusHttpResponse.statusCode {
            case 200:
                print("✅ 获取状态成功，开始解析")
                do {
                    let status = try JSONDecoder().decode(OpenWRTStatus.self, from: statusData)
                    print("✅ 解析成功: \(status)")
                    return status
                } catch {
                    print("❌ 解析错误: \(error)")
                    throw NetworkError.invalidResponse
                }
            case 401:
                print("🔒 状态请求未授权")
                throw NetworkError.unauthorized
            default:
                print("❌ 状态请求失败: \(statusHttpResponse.statusCode)")
                throw NetworkError.serverError(statusHttpResponse.statusCode)
            }
        } catch {
            print("❌ 请求错误: \(error)")
            throw ClashServer.handleNetworkError(error)
        }
    }
    
    // 添加获取 Clash 配置的方法
    func fetchClashConfig(_ server: ClashServer) async throws -> ClashConfig {
        guard let username = server.openWRTUsername,
              let password = server.openWRTPassword else {
            throw NetworkError.unauthorized
        }
        
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.url):\(server.port)/cgi-bin/luci/admin/services/openclash/config") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // 添加基本认证
        let authString = "\(username):\(password)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        let session = makeURLSession(for: server)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                return try JSONDecoder().decode(ClashConfig.self, from: data)
            case 401:
                throw NetworkError.unauthorized
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch {
            throw ClashServer.handleNetworkError(error)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        print("🔄 收到重定向请求")
        print("从: \(task.originalRequest?.url?.absoluteString ?? "unknown")")
        print("到: \(request.url?.absoluteString ?? "unknown")")
        print("状态码: \(response.statusCode)")
        completionHandler(nil)  // 不跟随重定向
    }
} 