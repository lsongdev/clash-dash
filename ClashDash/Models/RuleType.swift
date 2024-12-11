import SwiftUI

enum RuleType: String, CaseIterable {
    case domain = "DOMAIN"
    case domainSuffix = "DOMAIN-SUFFIX"
    case domainKeyword = "DOMAIN-KEYWORD"
    case processName = "PROCESS-NAME"
    case ipCidr = "IP-CIDR"
    case srcIpCidr = "SRC-IP-CIDR"
    case dstPort = "DST-PORT"
    case srcPort = "SRC-PORT"
    
    var description: String {
        switch self {
        case .domain: return "匹配域名"
        case .domainSuffix: return "匹配域名后缀"
        case .domainKeyword: return "匹配域名关键字"
        case .processName: return "匹配路由自身进程"
        case .ipCidr: return "匹配数据目标IP"
        case .srcIpCidr: return "匹配数据发起IP"
        case .dstPort: return "匹配数据目标端口"
        case .srcPort: return "匹配数据源端口"
        }
    }
    
    var iconName: String {
        switch self {
        case .domain: return "globe"
        case .domainSuffix: return "globe.americas"
        case .domainKeyword: return "magnifyingglass"
        case .processName: return "terminal"
        case .ipCidr: return "network"
        case .srcIpCidr: return "arrow.up.forward"
        case .dstPort: return "arrow.down.forward"
        case .srcPort: return "arrow.up"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .domain: return .purple
        case .domainSuffix: return .indigo
        case .domainKeyword: return .blue
        case .processName: return .green
        case .ipCidr: return .orange
        case .srcIpCidr: return .red
        case .dstPort: return .teal
        case .srcPort: return .mint
        }
    }
    
    var example: String {
        switch self {
        case .domain: return "示例：www.example.com"
        case .domainSuffix: return "示例：example.com"
        case .domainKeyword: return "示例：example"
        case .processName: return "示例：curl"
        case .ipCidr: return "示例：192.168.1.0/24"
        case .srcIpCidr: return "示例：192.168.1.100/32"
        case .dstPort: return "示例：80"
        case .srcPort: return "示例：8080"
        }
    }
} 