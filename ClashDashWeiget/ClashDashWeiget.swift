import SwiftUI
import WidgetKit

private enum WidgetConnectionState {
    case online, partial, cached, offline, unconfigured

    var title: String {
        switch self {
        case .online: "Connected"
        case .partial: "Limited"
        case .cached: "Cached"
        case .offline: "Offline"
        case .unconfigured: "Set up"
        }
    }

    var color: Color {
        switch self {
        case .online: .green
        case .partial: .orange
        case .cached: .secondary
        case .offline: .red
        case .unconfigured: .secondary
        }
    }
}

struct ClashDashEntry: TimelineEntry {
    let date: Date
    let serverName: String?
    let metrics: WidgetMetrics?
    fileprivate let state: WidgetConnectionState
}

struct ClashDashProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClashDashEntry {
        ClashDashEntry(date: .now, serverName: "Home server",
                       metrics: WidgetMetrics(serverID: UUID(), timestamp: .now,
                                              downloadBytesPerSecond: 638_000,
                                              uploadBytesPerSecond: 35_000,
                                              activeConnections: 12), state: .online)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClashDashEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : cachedEntry(state: .cached))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClashDashEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5 * 60))))
        }
    }

    private func cachedEntry(state: WidgetConnectionState = .offline) -> ClashDashEntry {
        guard let server = WidgetStore.server else {
            return ClashDashEntry(date: .now, serverName: nil, metrics: nil, state: .unconfigured)
        }
        let metrics = WidgetStore.metrics.flatMap { $0.serverID == server.id ? $0 : nil }
        return ClashDashEntry(date: .now, serverName: server.name, metrics: metrics, state: state)
    }

    private func currentEntry() async -> ClashDashEntry {
        guard let server = WidgetStore.server else { return cachedEntry() }
        async let traffic = WidgetControllerClient.fetchTraffic(from: server)
        async let connections = WidgetControllerClient.fetchConnections(from: server)
        let (trafficResult, connectionCount) = await (traffic, connections)
        guard trafficResult != nil || connectionCount != nil else { return cachedEntry() }

        let metrics = WidgetMetrics(
            serverID: server.id, timestamp: .now,
            downloadBytesPerSecond: trafficResult?.down,
            uploadBytesPerSecond: trafficResult?.up,
            activeConnections: connectionCount
        )
        WidgetStore.saveMetrics(metrics)
        return ClashDashEntry(date: .now, serverName: server.name, metrics: metrics,
                              state: trafficResult != nil && connectionCount != nil ? .online : .partial)
    }
}

private enum WidgetControllerClient {
    struct Traffic: Decodable {
        let up: Int
        let down: Int
    }

    static func fetchConnections(from server: WidgetServerConfiguration) async -> Int? {
        var request = URLRequest(url: server.baseURL.appendingPathComponent("connections"))
        request.timeoutInterval = 6
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let connections = root["connections"] as? [Any] else { return nil }
            return connections.count
        } catch {
            return nil
        }
    }

    static func fetchTraffic(from server: WidgetServerConfiguration) async -> Traffic? {
        guard var components = URLComponents(url: server.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/traffic"
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        if !server.secret.isEmpty {
            request.setValue("Bearer \(server.secret)", forHTTPHeaderField: "Authorization")
        }

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var completed = false
            let finish: (Traffic?) -> Void = { value in
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                completed = true
                continuation.resume(returning: value)
            }

            let task = URLSession.shared.webSocketTask(with: request)
            task.resume()
            task.receive { result in
                defer { task.cancel(with: .goingAway, reason: nil) }
                guard case .success(let message) = result else {
                    finish(nil)
                    return
                }
                let data: Data
                switch message {
                case .string(let text): data = Data(text.utf8)
                case .data(let received): data = received
                @unknown default:
                    finish(nil)
                    return
                }
                finish(try? JSONDecoder().decode(Traffic.self, from: data))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
                task.cancel(with: .goingAway, reason: nil)
                finish(nil)
            }
        }
    }
}

private enum WidgetSpeed {
    static func parts(_ bytes: Int?) -> (value: String, unit: String) {
        guard let bytes else { return ("—", "") }
        let value = Double(max(0, bytes))
        if value < 1_024 { return ("\(Int(value))", "B/s") }
        if value < 1_048_576 { return (String(format: "%.1f", value / 1_024), "KB/s") }
        if value < 1_073_741_824 { return (String(format: "%.1f", value / 1_048_576), "MB/s") }
        return (String(format: "%.1f", value / 1_073_741_824), "GB/s")
    }
}

private struct WidgetMetric: View {
    let label: String
    let symbol: String
    let color: Color
    let bytes: Int?
    let prominent: Bool

    var body: some View {
        let speed = WidgetSpeed.parts(bytes)
        VStack(alignment: .leading, spacing: prominent ? 7 : 3) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .medium))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(speed.value)
                    .font(.system(size: prominent ? 27 : 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(speed.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ClashDashWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClashDashEntry

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
            Text("Clash Dash")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Circle()
                .fill(entry.state.color)
                .frame(width: 7, height: 7)
                .accessibilityLabel(entry.state.title)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(entry.serverName ?? "No server")
                .lineLimit(1)
            Spacer(minLength: 3)
            if let timestamp = entry.metrics?.timestamp {
                Text(timestamp, style: .relative).lineLimit(1)
            } else {
                Text(entry.state.title)
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 25))
                .foregroundStyle(.blue)
            Text("Add a server")
                .font(.system(size: 17, weight: .semibold))
            Text("Open Clash Dash to connect")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 6)
            WidgetMetric(label: "Download", symbol: "arrow.down", color: .blue,
                         bytes: entry.metrics?.downloadBytesPerSecond, prominent: true)
            Spacer(minLength: 5)
            WidgetMetric(label: "Upload", symbol: "arrow.up", color: .green,
                         bytes: entry.metrics?.uploadBytesPerSecond, prominent: false)
            Spacer(minLength: 6)
            footer
        }
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text(entry.serverName ?? "No server")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
            Spacer(minLength: 9)
            HStack(alignment: .top, spacing: 16) {
                WidgetMetric(label: "Download", symbol: "arrow.down", color: .blue,
                             bytes: entry.metrics?.downloadBytesPerSecond, prominent: true)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1, height: 48)
                Spacer(minLength: 0)
                WidgetMetric(label: "Upload", symbol: "arrow.up", color: .green,
                             bytes: entry.metrics?.uploadBytesPerSecond, prominent: true)
            }
            Spacer(minLength: 9)
            HStack(spacing: 5) {
                Image(systemName: "link")
                Text(entry.metrics?.activeConnections.map(String.init) ?? "—")
                    .fontWeight(.semibold)
                Text("connections")
                Spacer()
                if let timestamp = entry.metrics?.timestamp {
                    Text(timestamp, style: .relative)
                } else {
                    Text(entry.state.title)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        Group {
            if entry.state == .unconfigured {
                emptyState
            } else if family == .systemSmall {
                smallWidget
            } else {
                mediumWidget
            }
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

struct ClashDashWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStore.kind, provider: ClashDashProvider()) { entry in
            ClashDashWidgetView(entry: entry)
        }
        .configurationDisplayName("Clash Dash")
        .description("Download, upload, and connections at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ClashDashWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClashDashWidget()
    }
}

#Preview(as: .systemSmall) {
    ClashDashWidget()
} timeline: {
    ClashDashEntry(date: .now, serverName: "Home server",
                   metrics: WidgetMetrics(serverID: UUID(), timestamp: .now,
                                          downloadBytesPerSecond: 638_000,
                                          uploadBytesPerSecond: 35_000,
                                          activeConnections: 12), state: .online)
}

#Preview(as: .systemMedium) {
    ClashDashWidget()
} timeline: {
    ClashDashEntry(date: .now, serverName: "Home server",
                   metrics: WidgetMetrics(serverID: UUID(), timestamp: .now,
                                          downloadBytesPerSecond: 638_000,
                                          uploadBytesPerSecond: 35_000,
                                          activeConnections: 12), state: .online)
}
