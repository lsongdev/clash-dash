import SwiftUI

struct ClashServer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: String
    var secret: String
    var status: ServerStatus
    var version: String?
    var useSSL: Bool
    var errorMessage: String?
    var serverType: ServerType?
    var isQuickLaunch: Bool = false
    
    enum ServerType: String, Codable {
        case unknown = "Unknown"
        case meta = "Meta"
        case premium = "Premium"
        case singbox = "Sing-Box"
    }
    
    init(id: UUID = UUID(), 
         name: String = "", 
         host: String = "",
         port: String = "",
         secret: String = "", 
         status: ServerStatus = .unknown, 
         version: String? = nil,
         useSSL: Bool = false,
         isQuickLaunch: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.secret = secret
        self.status = status
        self.version = version
        self.useSSL = useSSL
        self.isQuickLaunch = isQuickLaunch
    }
    
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        return "\(host):\(port)"
    }
    
    var baseURL: URL? {
        let cleanURL = host.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(cleanURL):\(port)")
    }
    
    var proxyProvidersURL: URL? {
        baseURL?.appendingPathComponent("providers/proxies")
    }
    
    var isValid: Bool {
        host.isEmpty || port.isEmpty || secret.isEmpty
    }
    
    func makeRequest(url: URL?) throws -> URLRequest {
        guard let url = url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        return request
    }
    
    static func handleNetworkError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return .serverError(0)  // 使用状态码 0 表示连接问题
            case .secureConnectionFailed, .serverCertificateHasBadDate,
                 .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .clientCertificateRejected,
                 .clientCertificateRequired:
                return .serverError(-1)  // 使用状态码 -1 表示 SSL 问题
            case .userAuthenticationRequired:
                return .unauthorized(message: "认证失败")
            case .badServerResponse, .cannotParseResponse:
                return .invalidResponse(message: "无效的服务器响应，请检查服务器配置")
            default:
                return .unknown(error)
            }
        }
        
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        return .unknown(error)
    }
}

enum ServerStatus: String, Codable {
    case ok
    case unauthorized
    case error
    case unknown
    
    var color: Color {
        switch self {
        case .ok: return .green
        case .unauthorized: return .yellow
        case .error: return .red
        case .unknown: return .gray
        }
    }
    
    var text: String {
        switch self {
        case .ok: return "200 OK"
        case .unauthorized: return "401 Unauthorized"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
} 
