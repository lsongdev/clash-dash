import Foundation

struct WidgetServerConfiguration: Codable {
    let id: UUID
    let name: String
    let baseURL: URL
    let secret: String
}

struct WidgetMetrics: Codable {
    let serverID: UUID
    let timestamp: Date
    let downloadBytesPerSecond: Int?
    let uploadBytesPerSecond: Int?
    let activeConnections: Int?
}

enum WidgetStore {
    static let kind = "ClashDashWidget"

    private static let suiteName = "group.org.lsong.clashdash"
    private static let serverKey = "WidgetServerConfiguration"
    private static let metricsKey = "WidgetMetrics"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static var server: WidgetServerConfiguration? {
        guard let data = defaults?.data(forKey: serverKey) else { return nil }
        return try? JSONDecoder().decode(WidgetServerConfiguration.self, from: data)
    }

    static var metrics: WidgetMetrics? {
        guard let data = defaults?.data(forKey: metricsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetMetrics.self, from: data)
    }

    static func saveServer(_ server: WidgetServerConfiguration?) {
        guard let defaults else { return }
        guard let server else {
            defaults.removeObject(forKey: serverKey)
            defaults.removeObject(forKey: metricsKey)
            return
        }

        if let previous = self.server,
           previous.id != server.id || previous.baseURL != server.baseURL || previous.secret != server.secret {
            defaults.removeObject(forKey: metricsKey)
        }
        if let data = try? JSONEncoder().encode(server) {
            defaults.set(data, forKey: serverKey)
        }
    }

    static func saveMetrics(_ metrics: WidgetMetrics) {
        guard metrics.serverID == server?.id,
              let data = try? JSONEncoder().encode(metrics) else { return }
        defaults?.set(data, forKey: metricsKey)
    }
}
