import Foundation

/// Offline controller. All fixtures are fictional; this type never performs I/O.
final class DemoController {
    static let shared = DemoController()
    private let lock = NSLock()
    private var selected = "🇸🇬 Singapore"
    private var disabled: [String: Bool] = [:]
    private var closed = Set<String>()
    private var refreshed: [String: String] = [:]
    private var config = DemoController.initialConfig
    private static var initialConfig: [String: Any] { [
        "port": 7890, "socks-port": 7891, "redir-port": 0, "mixed-port": 7890,
        "allow-lan": true, "mode": "rule", "log-level": "info", "sniffing": true,
        "tun": ["enable": false, "device": "utun", "stack": "gvisor", "auto-route": true, "auto-detect-interface": true],
        "tuic-server": ["enable": false]
    ] }
    private let nodes = ["🇸🇬 Singapore", "🇯🇵 Tokyo", "🇺🇸 Los Angeles", "🇩🇪 Frankfurt"]
    private let started = Date()

    func reset() {
        lock.lock(); defer { lock.unlock() }
        selected = nodes[0]; disabled = [:]; closed = []; refreshed = [:]; config = Self.initialConfig
    }

    private func timestamp() -> String { ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: "Z", with: ".000000000Z") }
    private func proxy(_ name: String, index: Int = 0) -> [String: Any] {
        ["name": name, "type": name == "DIRECT" ? "Direct" : "Trojan", "alive": true,
         "history": [["time": timestamp(), "delay": name == "DIRECT" ? 1 : 38 + index * 27]]]
    }
    private func connections() -> [String: Any] {
        let elapsed = Int(Date().timeIntervalSince(started))
        let entries: [[String: Any]] = ["example.com", "images.example.org", "api.example.net"].enumerated().compactMap { index, host in
            let id = "demo-connection-\(index)"
            guard !closed.contains(id) else { return nil }
            return ["id": id, "metadata": ["network": "tcp", "type": "HTTPS", "sourceIP": "192.0.2.10",
                "sourcePort": "\(50000 + index)", "destinationIP": "203.0.113.\(index + 1)", "destinationPort": "443", "host": host, "dnsMode": "normal"],
                "upload": 100000 + elapsed * 4096, "download": 8000000 + elapsed * 131072,
                "start": ISO8601DateFormatter.withFractions.string(from: started),
                "chains": [selected, "Demo Proxy"], "rule": "DomainSuffix", "rulePayload": "example.com"]
        }
        return ["connections": entries, "uploadTotal": 124000000 + elapsed * 4096, "downloadTotal": 3480000000 + elapsed * 131072]
    }

    func stream(_ path: String) -> Data {
        lock.lock(); defer { lock.unlock() }
        let t = Date().timeIntervalSince(started)
        let value: [String: Any]
        switch path {
        case "traffic": value = ["up": Int(180000 + 70000 * sin(t / 3)), "down": Int(2800000 + 1500000 * sin(t / 5))]
        case "memory": value = ["inuse": Int(58000000 + 6000000 * sin(t / 7)), "oslimit": 0]
        case "connections": value = connections()
        default: value = ["type": "info", "payload": "[Demo] Simulated connection to example.com via \(selected)"]
        }
        return (try? JSONSerialization.data(withJSONObject: value)) ?? Data()
    }

    func respond(to request: URLRequest) throws -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        let url = request.url!
        let segments = url.path.split(separator: "/").map(String.init)
        let method = request.httpMethod ?? "GET"
        var bodyData = request.httpBody ?? Data()
        if bodyData.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                bodyData.append(buffer, count: count)
            }
        }
        let body = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any] ?? [:]
        var value: [String: Any] = [:]
        var status = 200
        switch segments.first {
        case "version": value = ["meta": true, "version": "Demo · 1.0"]
        case "proxies":
            if method == "PUT", segments.count == 2 {
                guard segments[1] == "Demo Proxy", let name = body["name"] as? String, nodes.contains(name) || name == "DIRECT" else { return (400, Data()) }
                selected = name; status = 204
            } else if segments.last == "delay" {
                value = ["delay": 52]
            } else {
                var proxies = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element, proxy($0.element, index: $0.offset)) })
                proxies["DIRECT"] = proxy("DIRECT")
                proxies["Demo Proxy"] = ["name": "Demo Proxy", "type": "Selector", "alive": true, "history": [], "all": nodes + ["DIRECT"], "now": selected]
                proxies["Demo Auto"] = ["name": "Demo Auto", "type": "URLTest", "alive": true, "history": [], "all": nodes, "now": nodes[0]]
                value = ["proxies": proxies]
            }
        case "group": value = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element, 38 + $0.offset * 27) })
        case "rules":
            if method == "PATCH" {
                for (key, value) in body { if let flag = value as? Bool { disabled[key] = flag } }
                status = 204
            } else {
                let fixtures = [("DOMAIN-SUFFIX", "example.com", "Demo Proxy"), ("RULE-SET", "Demo Streaming", "Demo Proxy"), ("GEOIP", "LAN", "DIRECT"), ("MATCH", "", "Demo Auto")]
                value = ["rules": fixtures.enumerated().map { index, rule -> [String: Any] in
                    ["index": index, "type": rule.0, "payload": rule.1, "proxy": rule.2, "extra": ["disabled": disabled[String(index)] ?? false]]
                }]
            }
        case "providers":
            let isProxy = segments.dropFirst().first == "proxies"
            let name = isProxy ? "Demo Subscription" : "Demo Streaming"
            if method == "PUT" { refreshed[name] = timestamp(); status = 204 }
            else if isProxy {
                value = ["providers": [name: ["name": name, "type": "Proxy", "vehicleType": "HTTP",
                    "proxies": nodes.enumerated().map { proxy($0.element, index: $0.offset) },
                    "updatedAt": refreshed[name] ?? timestamp(),
                    "subscriptionInfo": ["Upload": 2147483648, "Download": 19327352832, "Total": 107374182400, "Expire": Int(Date().addingTimeInterval(90 * 86400).timeIntervalSince1970)]]]]
            } else {
                value = ["providers": [name: ["name": name, "behavior": "domain", "type": "Rule", "vehicleType": "HTTP", "format": "yaml", "ruleCount": 128, "updatedAt": refreshed[name] ?? timestamp()]]]
            }
        case "configs":
            if method == "PATCH" {
                for (key, value) in body {
                    if let nested = value as? [String: Any], var existing = config[key] as? [String: Any] { existing.merge(nested) { _, new in new }; config[key] = existing }
                    else { config[key] = value }
                }
                status = 204
            } else if method == "GET" { value = config } else { status = 204 }
        case "connections":
            if method == "DELETE" {
                if segments.count > 1 { closed.insert(segments[1]) }
                else { closed.formUnion((0..<3).map { "demo-connection-\($0)" }) }
                status = 204
            } else { value = connections() }
        case "dns":
            let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "type" }?.value
            value = ["Status": 0, "Answer": [["TTL": 300, "data": type == "AAAA" ? "2001:db8::1" : type == "MX" ? "10 mail.example.com." : "203.0.113.1"]]]
        case "restart": selected = nodes[0]; status = 204
        case "upgrade", "cache": status = 204
        case nil: value = ["message": "ClashHandy offline demo"]
        default: status = 404; value = ["message": "Unsupported demo endpoint"]
        }
        return (status, status == 204 ? Data() : try JSONSerialization.data(withJSONObject: value))
    }
}

private extension ISO8601DateFormatter {
    static var withFractions: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
