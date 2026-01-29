//
//  ClashAPI.swift
//  ClashDash
//
//  Created by Lsong on 1/29/26.
//

import Foundation

// MARK: - Clash API Response Models
struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

// MARK: - Clash API
class ClashAPI: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private var activeSessions: [URLSession] = []
    
    // MARK: - URL Session Management
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
        activeSessions.append(session)
        return session
    }
    
    private func makeRequest(for server: ClashServer, path: String) -> URLRequest? {
        let scheme = server.useSSL ? "https" : "http"
        var urlComponents = URLComponents()
        
        urlComponents.scheme = scheme
        urlComponents.host = server.host
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
    
    // MARK: - URLSessionDelegate
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // MARK: - Server Version Check
    @MainActor
    func checkServerVersion(_ server: ClashServer) async -> (status: ServerStatus, version: String?, serverType: ClashServer.ServerType?, errorMessage: String?) {
        guard let request = makeRequest(for: server, path: "/version") else {
            return (.error, nil, nil, "无效的请求")
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
                return (.error, nil, nil, "无效的响应")
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let versionResponse = try JSONDecoder().decode(VersionResponse.self, from: data)
                    let serverType = determineServerType(from: versionResponse)
                    return (.ok, versionResponse.version, serverType, nil)
                } catch {
                    if let versionDict = try? JSONDecoder().decode([String: String].self, from: data),
                       let version = versionDict["version"] {
                        return (.ok, version, nil, nil)
                    } else {
                        return (.error, nil, nil, "无效的响应格式")
                    }
                }
            case 401:
                return (.unauthorized, nil, nil, "认证失败，请检查密钥")
            case 404:
                return (.error, nil, nil, "API 路径不存在")
            case 500...599:
                return (.error, nil, nil, "服务器错误: \(httpResponse.statusCode)")
            default:
                return (.error, nil, nil, "未知响应: \(httpResponse.statusCode)")
            }
        } catch let urlError as URLError {
            let errorMessage: String
            switch urlError.code {
            case .cancelled:
                errorMessage = "请求被取消"
            case .secureConnectionFailed:
                errorMessage = "SSL/TLS 连接失败"
            case .serverCertificateUntrusted:
                errorMessage = "证书不受信任"
            case .timedOut:
                errorMessage = "连接超时"
            case .cannotConnectToHost:
                errorMessage = "无法连接到服务器"
            case .notConnectedToInternet:
                errorMessage = "网络未连接"
            default:
                errorMessage = "网络错误"
            }
            return (.error, nil, nil, errorMessage)
        } catch {
            return (.error, nil, nil, "未知错误")
        }
    }
    
    // MARK: - Helper Methods
    private func determineServerType(from response: VersionResponse) -> ClashServer.ServerType {
        if response.premium == true {
            return .premium
        } else if response.meta == true {
            return .meta
        }
        return .unknown
    }
}
