import Foundation

struct ClashConfig: Codable {
    let port: Int
    let socksPort: Int
    let redirPort: Int
    let mixedPort: Int?
    let tproxyPort: Int?
    let allowLan: Bool
    let mode: String
    let logLevel: String
    let secret: String?
    let sniffing: Bool?
    let interfaceName: String?
    let tun: TunConfig?
    let tuicServer: TuicServer?
    
    struct TunConfig: Codable {
        let enable: Bool
        let device: String
        let stack: String
        let autoRoute: Bool
        let autoDetectInterface: Bool
        
        enum CodingKeys: String, CodingKey {
            case enable
            case device
            case stack
            case autoRoute = "auto-route"
            case autoDetectInterface = "auto-detect-interface"
        }
    }
    
    struct TuicServer: Codable {
        let enable: Bool
    }
    
    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case redirPort = "redir-port"
        case mixedPort = "mixed-port"
        case tproxyPort = "tproxy-port"
        case allowLan = "allow-lan"
        case mode
        case logLevel = "log-level"
        case secret
        case sniffing
        case interfaceName = "interface-name"
        case tun
        case tuicServer = "tuic-server"
    }
    
    var isMetaServer: Bool {
        return tuicServer != nil
    }
} 