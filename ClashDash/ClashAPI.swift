//
//  ClashAPI.swift
//  ClashDash
//
//  Created by Lsong on 1/29/26.
//

import Foundation

struct Rule: Identifiable, Hashable {
    let id: Int
    let type: String
    let payload: String
    let proxy: String
    let size: Int?
    var isDisabled: Bool

    func recordCount(in providers: [RuleProvider]) -> Int? {
        if let size, size >= 0 { return size }
        let normalizedType = type.uppercased().replacingOccurrences(of: "-", with: "")
        guard normalizedType == "RULESET",
              let count = providers.first(where: { $0.name == payload })?.ruleCount,
              count >= 0 else { return nil }
        return count
    }
    
    var sectionKey: String {
        let firstChar = String(payload.prefix(1)).uppercased()
        return firstChar.first?.isLetter == true ? firstChar : "#"
    }
}

struct RuleProvider: Codable, Identifiable {
    var id: String { name }
    var name: String
    let behavior: String
    let type: String
    let ruleCount: Int
    let updatedAt: String
    let format: String?  // 改为可选类型
    let vehicleType: String
    
    var formattedUpdateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'"
        if let date = formatter.date(from: updatedAt) {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return "Unknown"
    }
}


// Response models
private struct RulesResponse: Decodable {
    let rules: [RuleResponseItem]
}

private struct RuleResponseItem: Decodable {
    let index: Int?
    let type: String
    let payload: String
    let proxy: String
    let size: Int?
    let extra: Extra?

    struct Extra: Decodable {
        let disabled: Bool?
    }
}

struct ProxyDetail: Codable, Identifiable {
    let id: String?
    let name: String
    let type: String
    let alive: Bool?
    let history: [ProxyHistory]
    // group
    let all: [String]?
    let now: String?
    //
    var delay: Int {
        return history.last?.delay ?? 0
    }
    
    var isGroup: Bool {
        return all != nil
    }

    static func unresolved(name: String) -> ProxyDetail {
        ProxyDetail(id: nil, name: name, type: "Unknown", alive: nil, history: [], all: nil, now: nil)
    }
}

/// Keeps the order reported by each group's `all` array, including names that
/// have no detail object in either API response.
struct ProxyCatalog {
    let groups: [ProxyDetail]
    private let detailsByName: [String: ProxyDetail]

    init(proxies: [ProxyDetail], providers: [ProxyProvider]) {
        groups = proxies.filter(\.isGroup)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        var details = Dictionary(proxies.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for provider in providers {
            for proxy in provider.proxies where details[proxy.name] == nil {
                details[proxy.name] = proxy
            }
        }
        detailsByName = details
    }

    func nodes(in group: ProxyDetail) -> [ProxyDetail] {
        (group.all ?? []).map { detailsByName[$0] ?? .unresolved(name: $0) }
    }

    func currentNode(in group: ProxyDetail) -> ProxyDetail? {
        group.now.flatMap { detailsByName[$0] }
    }
}

struct ProxyHistory: Codable {
    let time: String
    let delay: Int
}

struct ProxyProvider: Codable {
    let name: String
    let type: String
    let vehicleType: String
    let proxies: [ProxyDetail]
    let testUrl: String?
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?

    var canRefresh: Bool {
        vehicleType.caseInsensitiveCompare("HTTP") == .orderedSame
    }
}

struct SubscriptionInfo: Codable {
    let upload: Int64
    let download: Int64
    let total: Int64
    let expire: Int64
    
    enum CodingKeys: String, CodingKey {
        case upload = "Upload"
        case download = "Download"
        case total = "Total"
        case expire = "Expire"
    }
}


struct RuleProvidersResponse: Codable {
    let providers: [String: RuleProvider]
}

struct ProxyResponse: Codable {
    let proxies: [String: ProxyDetail]
}


struct ProxyProvidersResponse: Codable {
    let providers: [String: ProxyProvider]
}



// MARK: - Clash API Response Models
struct VersionResponse: Codable {
    let meta: Bool?
    let premium: Bool?
    let version: String
}

private struct DelayResponse: Codable {
    let delay: Int
}

// MARK: - Clash API
class ClashAPI: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        super.init()
    }

    private func apiURL(
        server: ClashServer,
        pathSegments: [String],
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        let path = pathSegments.map {
            $0.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? $0
        }.joined(separator: "/")

        guard var components = URLComponents(string: "\(server.url.absoluteString)/\(path)") else {
            throw NetworkError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }
        return url
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(message: "The server returned an invalid response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized(message: "Authentication failed. Check the Secret.")
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }
    
    func getVersion(_ server: ClashServer) async throws -> String {
        let request = server.makeRequest(path: "/version")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let res = try JSONDecoder().decode(VersionResponse.self, from: data)
        return res.version
    }
    
    func fetchRules(server: ClashServer) async throws -> [Rule] {
        let request = server.makeRequest(path: "rules")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let res = try JSONDecoder().decode(RulesResponse.self, from: data)
        return res.rules.enumerated().map { offset, item in
            Rule(
                id: item.index ?? offset,
                type: item.type,
                payload: item.payload,
                proxy: item.proxy,
                size: item.size,
                isDisabled: item.extra?.disabled ?? false
            )
        }
    }

    func setRuleDisabled(server: ClashServer, ruleIndex: Int, disabled: Bool) async throws {
        var request = server.makeRequest(path: "rules/disable", method: "PATCH")
        request.httpBody = try JSONEncoder().encode([String(ruleIndex): disabled])
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }
    
    func fetchRuleProviders(server: ClashServer) async throws -> [RuleProvider] {
        let request = server.makeRequest(path: "providers/rules")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let res = try JSONDecoder().decode(RuleProvidersResponse.self, from: data)
        return res.providers.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    func fetchProxies(server: ClashServer) async throws -> [ProxyDetail] {
        let request = server.makeRequest(path: "proxies")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let res = try JSONDecoder().decode(ProxyResponse.self, from: data)
        return res.proxies.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    func fetchProxyGroups(server: ClashServer) async throws -> [ProxyDetail] {
        let proxies = try await fetchProxies(server: server)
        return proxies.compactMap { proxy in
            guard proxy.isGroup else { return nil }
            return proxy
        }
    }

    func selectProxy(server: ClashServer, groupName: String, proxyName: String) async throws {
        let url = try apiURL(server: server, pathSegments: ["proxies", groupName])
        var request = server.makeRequest(path: "proxies", method: "PUT")
        request.url = url
        request.httpBody = try JSONEncoder().encode(["name": proxyName])

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    func testProxyGroupDelay(
        server: ClashServer,
        groupName: String,
        testURL: String,
        timeout: Int
    ) async throws -> [String: Int] {
        let url = try apiURL(
            server: server,
            pathSegments: ["group", groupName, "delay"],
            queryItems: [
                URLQueryItem(name: "url", value: testURL),
                URLQueryItem(name: "timeout", value: String(timeout))
            ]
        )
        var request = server.makeRequest(path: "group")
        request.url = url
        request.timeoutInterval = TimeInterval(timeout) / 1000 + 2
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([String: Int].self, from: data)
    }

    func testProxyDelay(
        server: ClashServer,
        proxyName: String,
        testURL: String,
        timeout: Int
    ) async throws -> Int {
        let url = try apiURL(
            server: server,
            pathSegments: ["proxies", proxyName, "delay"],
            queryItems: [
                URLQueryItem(name: "url", value: testURL),
                URLQueryItem(name: "timeout", value: String(timeout))
            ]
        )
        var request = server.makeRequest(path: "proxies")
        request.url = url
        request.timeoutInterval = TimeInterval(timeout) / 1000 + 2
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode(DelayResponse.self, from: data).delay
    }
    
    func fetchProxyProviders(server: ClashServer) async throws -> [ProxyProvider] {
        let request = server.makeRequest(path: "providers/proxies")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let providersResponse = try JSONDecoder().decode(ProxyProvidersResponse.self, from: data)
        let providers: [ProxyProvider] = providersResponse.providers.compactMap { _, provider in
            // Clash also returns a virtual "default" provider for built-in proxies.
            guard provider.vehicleType != "Compatible" || provider.subscriptionInfo != nil else {
                return nil
            }
            return provider
        }
        return providers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func refreshProxyProvider(server: ClashServer, name: String) async throws {
        let url = try apiURL(server: server, pathSegments: ["providers", "proxies", name])
        var request = server.makeRequest(path: "providers/proxies", method: "PUT")
        request.url = url
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }
    
    func refreshRulesProvider(server: ClashServer, name: String) async throws {
        let url = try apiURL(server: server, pathSegments: ["providers", "rules", name])
        var request = server.makeRequest(path: "providers/rules", method: "PUT")
        request.url = url
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }
}




// API 响应模型

// 添加 ProviderResponse 结构体
struct ProviderResponse: Codable {
    let type: String
    let vehicleType: String
    let proxies: [ProxyInfo]?
    let testUrl: String?
    let subscriptionInfo: SubscriptionInfo?
    let updatedAt: String?
}

// 添加 Extra 结构体定义
struct Extra: Codable {
    let alpn: [String]?
    let tls: Bool?
    let skip_cert_verify: Bool?
    let servername: String?
}

struct ProxyInfo: Codable {
    let name: String
    let type: String
    let alive: Bool
    let history: [ProxyHistory]
    let extra: Extra?
    let id: String?
    let tfo: Bool?
    let xudp: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case name, type, alive, history, extra, id, tfo, xudp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        alive = try container.decode(Bool.self, forKey: .alive)
        history = try container.decode([ProxyHistory].self, forKey: .history)
        
        // Meta 服务器特有的字段设为选
        extra = try container.decodeIfPresent(Extra.self, forKey: .extra)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        tfo = try container.decodeIfPresent(Bool.self, forKey: .tfo)
        xudp = try container.decodeIfPresent(Bool.self, forKey: .xudp)
    }
    
    // 添加编码方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(alive, forKey: .alive)
        try container.encode(history, forKey: .history)
        try container.encodeIfPresent(extra, forKey: .extra)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(tfo, forKey: .tfo)
        try container.encodeIfPresent(xudp, forKey: .xudp)
    }
}
