import Foundation

struct DNSAnswer: Codable {
    let TTL: Int
    let data: String
}

struct DNSResponse: Codable {
    let Answer: [DNSAnswer]?
    let Status: Int
}

class DNSQueryViewModel: ObservableObject {
    @Published var results: [String] = []
    
    private func makeRequest(server: ClashServer, domain: String, type: String) -> URLRequest? {
        guard let encodedDomain = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let scheme = server.useSSL ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(server.host):\(server.port)/dns/query?name=\(encodedDomain)&type=\(type)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func makeSession(server: ClashServer) -> URLSession {
        let config = URLSessionConfiguration.default
        if server.useSSL {
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        }
        return URLSession(configuration: config)
    }
    
    func queryDNS(server: ClashServer, domain: String, type: String) {
        guard let request = makeRequest(server: server, domain: domain, type: type) else {
            DispatchQueue.main.async { [weak self] in
                self?.results = ["Invalid request parameters"]
            }
            return
        }
        
        let session = makeSession(server: server)
        
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .secureConnectionFailed:
                            self?.results = ["SSL/TLS connection failed. Check the certificate settings."]
                        case .serverCertificateUntrusted:
                            self?.results = ["The server certificate is not trusted"]
                        case .clientCertificateRejected:
                            self?.results = ["The client certificate was rejected"]
                        default:
                            self?.results = ["Query failed: \(error.localizedDescription)"]
                        }
                    } else {
                        self?.results = ["Query failed: \(error.localizedDescription)"]
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self?.results = ["Authentication failed. Check the Secret."]
                        return
                    }
                }
                
                guard let data = data else {
                    self?.results = ["No response data"]
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(DNSResponse.self, from: data)
                    
                    if response.Status != 0 {
                        self?.results = ["Query failed (status \(response.Status))"]
                        return
                    }
                    
                    if let answers = response.Answer {
                        self?.results = answers.map { answer in
                            "\(answer.data) TTL: \(answer.TTL)"
                        }
                    } else {
                        self?.results = ["No records found"]
                    }
                } catch {
                    self?.results = ["Could not parse response: \(error.localizedDescription)"]
                }
            }
        }.resume()
    }
} 
