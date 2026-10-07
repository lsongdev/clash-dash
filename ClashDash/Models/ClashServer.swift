import SwiftUI

struct ClashServer: Identifiable, Codable, Hashable {
    static let demo = ClashServer(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000001")!, name: "Demo Server", host: "127.0.0.1", port: "0", status: .unknown, version: "Local Demo")
    /// Changes when a local listener is recreated, even if its port is reused.
    var connectionGeneration: UUID?
    var isDemo: Bool { id == Self.demo.id }
    var id: UUID = UUID()
    var name: String = ""
    var host: String = ""
    var port: String = ""
    var secret: String = ""
    var useSSL: Bool = false
    var status: ServerStatus = .unknown
    var version: String? = ""
    var errorMessage: String? = ""
    
    var isValid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Int(port.trimmingCharacters(in: .whitespacesAndNewlines)).map { (1...65535).contains($0) } == true
    }
    
    var displayName: String {
        return name.isEmpty ? "\(host):\(port)" : name
    }

    var endpointDescription: String {
        if isDemo { return "localhost:\(port) · Simulated data" }
        let scheme = useSSL ? "https" : "http"
        return "\(scheme)://\(host):\(port)"
    }

    /// 仅在连接参数变化时改变，避免状态刷新触发页面重复重连。
    var connectionIdentifier: String {
        "\(id.uuidString)|\(host)|\(port)|\(useSSL)|\(secret)|\(connectionGeneration?.uuidString ?? "")"
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
                return .unauthorized(message: "Authentication failed")
            case .badServerResponse, .cannotParseResponse:
                return .invalidResponse(message: "Invalid server response. Check the server settings.")
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
        case .ok: return "Online"
        case .unauthorized: return "Authentication failed"
        case .error: return "Connection failed"
        case .unknown: return "Not checked"
        }
    }
}
