import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse(message: String)
    case unauthorized(message: String)
    case serverError(Int)
    case missingDependencies(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse(let message):
            return message
        case .unauthorized(let message):
            return message
        case .serverError(let code):
            return "服务器错误（状态码：\(code)）"
        case .missingDependencies(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 