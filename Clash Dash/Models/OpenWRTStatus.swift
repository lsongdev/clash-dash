struct OpenWRTStatus: Codable {
    let web: Bool
    let clash: Bool
    let daip: String
    let dbForwardSSL: String
    let restrictedMode: String
    let cnPort: String
    let dase: String
    let watchdog: Bool
    let coreType: String
    
    enum CodingKeys: String, CodingKey {
        case web, clash, daip
        case dbForwardSSL = "db_forward_ssl"
        case restrictedMode = "restricted_mode"
        case cnPort = "cn_port"
        case dase, watchdog
        case coreType = "core_type"
    }
} 