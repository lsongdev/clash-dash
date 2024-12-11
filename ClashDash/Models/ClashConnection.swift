import Foundation

struct ClashConnection: Identifiable, Codable, Equatable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int
    let download: Int
    let start: Date
    let chains: [String]
    let rule: String
    let rulePayload: String
    let downloadSpeed: Double
    let uploadSpeed: Double
    let isAlive: Bool
    private let endTime: Date?
    
    // 添加一个标准初始化方法
    init(id: String, metadata: ConnectionMetadata, upload: Int, download: Int, start: Date, chains: [String], rule: String, rulePayload: String, downloadSpeed: Double, uploadSpeed: Double, isAlive: Bool, endTime: Date? = nil) {
        self.id = id
        self.metadata = metadata
        self.upload = upload
        self.download = download
        self.start = start
        self.chains = chains
        self.rule = rule
        self.rulePayload = rulePayload
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.isAlive = isAlive
        self.endTime = isAlive ? nil : (endTime ?? Date())
    }
    
    // 解码器初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        metadata = try container.decode(ConnectionMetadata.self, forKey: .metadata)
        upload = try container.decode(Int.self, forKey: .upload)
        download = try container.decode(Int.self, forKey: .download)
        chains = try container.decode([String].self, forKey: .chains)
        rule = try container.decode(String.self, forKey: .rule)
        rulePayload = try container.decode(String.self, forKey: .rulePayload)
        
        // 将速度字段设为可选，默认为 0
        downloadSpeed = try container.decodeIfPresent(Double.self, forKey: .downloadSpeed) ?? 0
        uploadSpeed = try container.decodeIfPresent(Double.self, forKey: .uploadSpeed) ?? 0
        
        // 设置 isAlive 默认为 true，因为从服务器接收的连接都是活跃的
        isAlive = try container.decodeIfPresent(Bool.self, forKey: .isAlive) ?? true
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        
        let dateString = try container.decode(String.self, forKey: .start)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            start = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .start,
                in: container,
                debugDescription: "Date string does not match expected format"
            )
        }
    }
    
    // 格式化方法保持不变
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter.string(from: start)
    }
    
    var formattedDuration: String {
        let endDate = isAlive ? Date() : (endTime ?? Date())
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start, to: endDate)
        var parts: [String] = []
        
        if let years = components.year, years > 0 {
            parts.append("\(years)y")
        }
        if let months = components.month, months > 0 {
            parts.append("\(months)m")
        }
        if let days = components.day, days > 0 {
            parts.append("\(days)d")
        }
        if let hours = components.hour, hours > 0 {
            parts.append("\(hours)h")
        }
        if let minutes = components.minute, minutes > 0 {
            parts.append("\(minutes)m")
        }
        if let seconds = components.second {
            parts.append("\(seconds)s")
        }
        
        return parts.joined(separator: " ")
    }
    
    var formattedChains: String {
        return chains.reversed().joined(separator: " → ")
    }
    
    // 预览数据
   static func preview() -> ClashConnection {
       return ClashConnection(
           id: "preview-id",
           metadata: ConnectionMetadata(
               network: "tcp",
               type: "HTTPS",
               sourceIP: "192.168.167.255",
               destinationIP: "142.250.188.14",
               sourcePort: "48078",
               destinationPort: "443",
               host: "www.youtube.com",
               dnsMode: "normal",
               processPath: "",
               specialProxy: "",
               sourceGeoIP: nil,
               destinationGeoIP: nil,
               sourceIPASN: nil,
               destinationIPASN: nil,
               inboundIP: nil,
               inboundPort: nil,
               inboundName: nil,
               inboundUser: nil,
               uid: nil,
               process: nil,
               specialRules: nil,
               remoteDestination: nil,
               dscp: nil,
               sniffHost: nil
           ),
           upload: 993946000,
           download: 993946000,
           start: Date().addingTimeInterval(-3600),
           chains: ["🇭🇰 香港 IEPL [01] [Air]", "Auto - UrlTest", "Proxy", "YouTube"],
           rule: "RuleSet",
           rulePayload: "YouTube",
           downloadSpeed: 102400000.0,
           uploadSpeed: 512.0,
           isAlive: true
       )
   }
}

struct ConnectionMetadata: Codable, Equatable {
    // 必需字段
    let network: String
    let type: String
    let sourceIP: String
    let sourcePort: String
    let destinationPort: String
    let host: String
    let dnsMode: String
    
    // 可选字段 - 修改为可选
    let destinationIP: String?  // 改为可选
    let processPath: String?    // 改为可选
    let specialProxy: String?   // 改为可选
    let sourceGeoIP: String?
    let destinationGeoIP: [String]?
    let sourceIPASN: String?
    let destinationIPASN: String?
    let inboundIP: String?
    let inboundPort: String?
    let inboundName: String?
    let inboundUser: String?
    let uid: Int?
    let process: String?
    let specialRules: String?
    let remoteDestination: String?
    let dscp: Int?
    let sniffHost: String?
    
    // 添加解码器初始化方法
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解码必需字段
        network = try container.decode(String.self, forKey: .network)
        type = try container.decode(String.self, forKey: .type)
        sourceIP = try container.decode(String.self, forKey: .sourceIP)
        sourcePort = try container.decode(String.self, forKey: .sourcePort)
        destinationPort = try container.decode(String.self, forKey: .destinationPort)
        host = try container.decode(String.self, forKey: .host)
        dnsMode = try container.decode(String.self, forKey: .dnsMode)
        
        // 解码可选字段
        destinationIP = try container.decodeIfPresent(String.self, forKey: .destinationIP)
        processPath = try container.decodeIfPresent(String.self, forKey: .processPath)
        specialProxy = try container.decodeIfPresent(String.self, forKey: .specialProxy)
        
        // 其他可选字段保持不变
        sourceGeoIP = try container.decodeIfPresent(String.self, forKey: .sourceGeoIP)
        destinationGeoIP = try container.decodeIfPresent([String].self, forKey: .destinationGeoIP)
        sourceIPASN = try container.decodeIfPresent(String.self, forKey: .sourceIPASN)
        destinationIPASN = try container.decodeIfPresent(String.self, forKey: .destinationIPASN)
        inboundIP = try container.decodeIfPresent(String.self, forKey: .inboundIP)
        inboundPort = try container.decodeIfPresent(String.self, forKey: .inboundPort)
        inboundName = try container.decodeIfPresent(String.self, forKey: .inboundName)
        inboundUser = try container.decodeIfPresent(String.self, forKey: .inboundUser)
        uid = try container.decodeIfPresent(Int.self, forKey: .uid)
        process = try container.decodeIfPresent(String.self, forKey: .process)
        specialRules = try container.decodeIfPresent(String.self, forKey: .specialRules)
        remoteDestination = try container.decodeIfPresent(String.self, forKey: .remoteDestination)
        dscp = try container.decodeIfPresent(Int.self, forKey: .dscp)
        sniffHost = try container.decodeIfPresent(String.self, forKey: .sniffHost)
    }
    
    // 添加标准初始化方法
    init(network: String, type: String, sourceIP: String, destinationIP: String?, sourcePort: String,
         destinationPort: String, host: String, dnsMode: String, processPath: String?, specialProxy: String?,
         sourceGeoIP: String? = nil, destinationGeoIP: [String]? = nil, sourceIPASN: String? = nil,
         destinationIPASN: String? = nil, inboundIP: String? = nil, inboundPort: String? = nil,
         inboundName: String? = nil, inboundUser: String? = nil, uid: Int? = nil, process: String? = nil,
         specialRules: String? = nil, remoteDestination: String? = nil, dscp: Int? = nil,
         sniffHost: String? = nil) {
        self.network = network
        self.type = type
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.host = host
        self.dnsMode = dnsMode
        self.processPath = processPath
        self.specialProxy = specialProxy
        self.sourceGeoIP = sourceGeoIP
        self.destinationGeoIP = destinationGeoIP
        self.sourceIPASN = sourceIPASN
        self.destinationIPASN = destinationIPASN
        self.inboundIP = inboundIP
        self.inboundPort = inboundPort
        self.inboundName = inboundName
        self.inboundUser = inboundUser
        self.uid = uid
        self.process = process
        self.specialRules = specialRules
        self.remoteDestination = remoteDestination
        self.dscp = dscp
        self.sniffHost = sniffHost
    }
}

// API 响应模型
struct ConnectionsResponse: Codable {
    let downloadTotal: Int
    let uploadTotal: Int
    let connections: [ClashConnection]
    let memory: Int?  // 设为可选
}

// 添加编码键
private enum CodingKeys: String, CodingKey {
    case id, metadata, upload, download, start, chains, rule, rulePayload
    case downloadSpeed, uploadSpeed, isAlive, endTime
} 
