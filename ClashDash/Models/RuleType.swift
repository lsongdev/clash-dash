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
        case .domain: return "Match exact domain"
        case .domainSuffix: return "Match domain suffix"
        case .domainKeyword: return "Match domain keyword"
        case .processName: return "Match process name"
        case .ipCidr: return "Match destination IP range"
        case .srcIpCidr: return "Match source IP range"
        case .dstPort: return "Match destination port"
        case .srcPort: return "Match source port"
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
        case .domain: return "Example: www.example.com"
        case .domainSuffix: return "Example: example.com"
        case .domainKeyword: return "Example: example"
        case .processName: return "Example: curl"
        case .ipCidr: return "Example: 192.168.1.0/24"
        case .srcIpCidr: return "Example: 192.168.1.100/32"
        case .dstPort: return "Example: 80"
        case .srcPort: return "Example: 8080"
        }
    }
}
