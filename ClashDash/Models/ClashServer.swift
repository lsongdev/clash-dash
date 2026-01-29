import SwiftUI

struct ClashServer: Identifiable, Codable, Hashable {
    let id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var port: String = ""
    var secret: String = ""
    var useSSL: Bool = false
    var status: ServerStatus = .unknown
    var version: String? = ""
    var errorMessage: String? = ""
    
    var isValid: Bool {
        host.isEmpty || port.isEmpty || secret.isEmpty
    }
    
    var displayName: String {
        return name.isEmpty ? "\(host):\(port)" : name
    }
    
    var url: URL {
        let host = host.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }
    
    func makeRequest(path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url.appendingPathComponent(path))
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpMethod = method
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
