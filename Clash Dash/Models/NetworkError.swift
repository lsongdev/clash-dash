import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case serverUnreachable
    case sslError
    case invalidResponse
    case unauthorized
    case serverError(Int)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .serverUnreachable:
            return "无法连接到服务器"
        case .sslError:
            return "SSL/TLS 连接错误"
        case .invalidResponse:
            return "无效的服务器响应"
        case .unauthorized:
            return "认证失败"
        case .serverError(let code):
            return "服务器错误: \(code)"
        case .unknownError(let error):
            return error.localizedDescription
        }
    }
} 