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

struct ProvidersResponse: Codable {
    let providers: [String: RuleProvider]
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
    
    func fetchRulesProviders(server: ClashServer) async throws -> [RuleProvider] {
        let request = server.makeRequest(path: "providers/rules")
        let (data, _) = try await URLSession.shared.data(for: request)
        let res = try JSONDecoder().decode(ProvidersResponse.self, from: data)
        let providers = res.providers.map { name, provider in
            var provider = provider
            provider.name = name
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
