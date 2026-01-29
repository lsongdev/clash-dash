//
//  ClashAPI.swift
//  ClashDash
//
//  Created by Lsong on 1/29/26.
//

import Foundation

struct Rule: Codable, Identifiable, Hashable {
    let type: String
    let payload: String
    let proxy: String
    let size: Int?  // 改为可选类型，适配原版 Clash 内核
    
    var id: String { "\(type)-\(payload)" }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Rule, rhs: Rule) -> Bool {
        lhs.id == rhs.id
    }
    
    var sectionKey: String {
        let firstChar = String(payload.prefix(1)).uppercased()
        return firstChar.first?.isLetter == true ? firstChar : "#"
    }
}

struct RuleProvider: Codable, Identifiable {
    var name: String
    let behavior: String
    let type: String
    let ruleCount: Int
    let updatedAt: String
    let format: String?  // 改为可选类型
    let vehicleType: String
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case behavior, type, ruleCount, updatedAt, format, vehicleType
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = ""
        self.behavior = try container.decode(String.self, forKey: .behavior)
        self.type = try container.decode(String.self, forKey: .type)
        self.ruleCount = try container.decode(Int.self, forKey: .ruleCount)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
        self.format = try container.decodeIfPresent(String.self, forKey: .format)  // 使用 decodeIfPresent
        self.vehicleType = try container.decode(String.self, forKey: .vehicleType)
    }
    
    var formattedUpdateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'"
        if let date = formatter.date(from: updatedAt) {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return "未知"
    }
}


// Response models
struct RulesResponse: Codable {
    let rules: [Rule]
}

struct ProxyDetail: Codable, Identifiable {
    let id: String?
    let name: String
    let type: String
    let alive: Bool
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

// MARK: - Clash API
class ClashAPI: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func getVersion(_ server: ClashServer) async throws {
        let request = server.makeRequest(path: "/version")
        let (data, res) = try await URLSession.shared.data(for: request)
        print(data)
    }
    
    func fetchRules(server: ClashServer) async throws -> [Rule] {
        let request = server.makeRequest(path: "rules")
        let (data, _) = try await URLSession.shared.data(for: request)
        let res = try JSONDecoder().decode(RulesResponse.self, from: data)
        return res.rules
    }
    
    func fetchRuleProviders(server: ClashServer) async throws -> [RuleProvider] {
        let request = server.makeRequest(path: "providers/rules")
        let (data, _) = try await URLSession.shared.data(for: request)
        let res = try JSONDecoder().decode(RuleProvidersResponse.self, from: data)
        let providers = res.providers.map { name, provider in
            return provider
        }
        return providers
    }
    
    func fetchProxies(server: ClashServer) async throws -> [ProxyDetail] {
        let request = server.makeRequest(path: "proxies")
        let (data, _) = try await URLSession.shared.data(for: request)
        let res = try JSONDecoder().decode(ProxyResponse.self, from: data)
        let proxies = res.proxies.compactMap { name, proxy in
            return proxy
        }
        return proxies
    }
    
    func fetchProxyGroups(server: ClashServer) async throws -> [ProxyDetail] {
        let proxies = try await fetchProxies(server: server)
        return proxies.compactMap { proxy in
            guard proxy.isGroup else { return nil }
            return proxy
        }
    }
    
    func fetchProxyProviders(server: ClashServer) async throws -> [ProxyProvider] {
        let request = server.makeRequest(path: "providers/proxies")
        let (data, _) = try await URLSession.shared.data(for: request)
        let providersResponse = try JSONDecoder().decode(ProxyProvidersResponse.self, from: data)
        let providers: [ProxyProvider] = providersResponse.providers.compactMap { name, provider in
            // 返回的数据 包含 default 和 vehicleType: "Compatible" 兼容代理组
            // 只有当 vehicleType 为 HTTP 或有 subscriptionInfo 时才包含
            guard provider.vehicleType == "HTTP" || provider.subscriptionInfo != nil else {
                return nil
            }
            return provider
        }
        return providers
    }
    
    func refreshRulesProvider(server: ClashServer, name: String) async throws {
        let request = server.makeRequest(path: "providers/rules/\(name)", method: "PUT")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 204 {
            // TODO:
        }
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
