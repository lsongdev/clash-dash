import SwiftUI

struct ProxiesTab: View {
    @ObservedObject private var appManager = AppManager.shared
    @State private var groups: [ProxyDetail] = []
    @State private var proxies: [ProxyDetail] = []
    @State private var providers: [ProxyProvider] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var server: ClashServer { appManager.currentServer }
    private var delayTestURL: String {
        UserDefaults.standard.string(forKey: "speedTestURL") ?? "http://www.gstatic.com/generate_204"
    }
    private var delayTestTimeout: Int {
        let value = UserDefaults.standard.integer(forKey: "speedTestTimeout")
        return value > 0 ? value : 5_000
    }

    var body: some View {
        Group {
            if isLoading && groups.isEmpty && providers.isEmpty {
                ProgressView("Loading proxies…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, groups.isEmpty && providers.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Proxies", systemImage: "network.slash")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Retry") { Task { await loadData(showLoading: true) } }
                }
            } else if groups.isEmpty && providers.isEmpty {
                ContentUnavailableView(
                    "No Proxies",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("This server returned no proxy groups or providers.")
                )
            } else {
                proxyList
            }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: server.connectionIdentifier) {
            await loadData(showLoading: true)
        }
        .navigationTitle("Proxies")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var proxyList: some View {
        List {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.red.opacity(0.08))
            }

            if !groups.isEmpty {
                Section("Proxy Groups") {
                    ForEach(groups, id: \.name) { group in
                        ProxyGroupCard(
                            group: group,
                            proxies: proxies,
                            onSelect: { proxyName in
                                try await appManager.api.selectProxy(
                                    server: server,
                                    groupName: group.name,
                                    proxyName: proxyName
                                )
                                await loadData(showLoading: false)
                            },
                            onTestGroup: {
                                _ = try await appManager.api.testProxyGroupDelay(
                                    server: server,
                                    groupName: group.name,
                                    testURL: delayTestURL,
                                    timeout: delayTestTimeout
                                )
                                await loadData(showLoading: false)
                            },
                            onTestNode: { proxyName in
                                _ = try await appManager.api.testProxyDelay(
                                    server: server,
                                    proxyName: proxyName,
                                    testURL: delayTestURL,
                                    timeout: delayTestTimeout
                                )
                                await loadData(showLoading: false)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }

            if !providers.isEmpty {
                Section("Proxy Providers") {
                    ForEach(providers, id: \.name) { provider in
                        ProxyProviderCard(provider: provider)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await loadData(showLoading: false) }
    }

    @MainActor
    private func loadData(showLoading: Bool) async {
        let requestedServer = server
        guard requestedServer.isValid else {
            groups = []
            proxies = []
            providers = []
            loadError = "Select a valid server first."
            return
        }

        if showLoading { isLoading = true }
        loadError = nil
        defer { isLoading = false }

        do {
            async let fetchedProxies = appManager.api.fetchProxies(server: requestedServer)
            async let fetchedProviders = appManager.api.fetchProxyProviders(server: requestedServer)
            let (newProxies, newProviders) = try await (fetchedProxies, fetchedProviders)
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }

            proxies = newProxies
            groups = newProxies
                .filter(\.isGroup)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            providers = newProviders
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch is CancellationError {
            return
        } catch {
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            loadError = error.localizedDescription
        }
    }
}

struct ProxyGroupCard: View {
    @State private var showingSelector = false

    let group: ProxyDetail
    let proxies: [ProxyDetail]
    let onSelect: (String) async throws -> Void
    let onTestGroup: () async throws -> Void
    let onTestNode: (String) async throws -> Void

    private var groupNodes: [ProxyDetail] {
        (group.all ?? []).compactMap { name in proxies.first { $0.name == name } }
    }

    private var currentNode: ProxyDetail? {
        guard let currentName = group.now else { return nil }
        return proxies.first { $0.name == currentName }
    }

    private var availableCount: Int { groupNodes.filter(\.alive).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: groupIcon)
                    .foregroundStyle(.tint)
                    .frame(width: 22)

                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(group.type)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())

                Spacer(minLength: 4)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showingSelector = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(currentStatusColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: nodeIcon(for: group.now ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(currentStatusColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Proxy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(group.now ?? "Not Selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()
                    ProxyDelayBadge(node: currentNode)
                }

                ProxyHealthBar(nodes: groupNodes)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                        Text("\(groupNodes.count) nodes")
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle")
                        Text("\(availableCount) available")
                    }
                    Spacer(minLength: 4)
                    Text("Tap to select")
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .sheet(isPresented: $showingSelector) {
            ProxySelectorView(
                groupName: group.name,
                currentName: group.now,
                nodes: groupNodes,
                onSelect: onSelect,
                onTestAll: onTestGroup,
                onTest: onTestNode
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var groupIcon: String {
        switch group.type.lowercased() {
        case "selector": return "slider.horizontal.3"
        case "urltest", "url-test": return "speedometer"
        case "fallback": return "arrow.triangle.branch"
        case "loadbalance", "load-balance": return "scale.3d"
        default: return "square.stack.3d.up"
        }
    }

    private var currentStatusColor: Color {
        guard let currentNode else { return .secondary }
        return currentNode.alive ? ProxyDelayColor.color(for: currentNode.delay) : .red
    }

    private func nodeIcon(for name: String) -> String {
        switch name {
        case "DIRECT": return "arrow.up.forward"
        case "REJECT": return "xmark"
        default: return "network"
        }
    }
}

struct ProxySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectingName: String?
    @State private var testingName: String?
    @State private var isTestingAll = false
    @State private var selectionError: String?

    let groupName: String
    let currentName: String?
    let nodes: [ProxyDetail]
    let onSelect: (String) async throws -> Void
    let onTestAll: () async throws -> Void
    let onTest: (String) async throws -> Void

    var body: some View {
        NavigationStack {
            List {
                if let selectionError {
                    Text(selectionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(nodes, id: \.name) { node in
                    HStack(spacing: 8) {
                        Button {
                            select(node)
                        } label: {
                            ProxyNodeRow(
                                node: node,
                                isSelected: node.name == currentName,
                                isLoading: selectingName == node.name
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isTestingAll || selectingName != nil || testingName != nil || node.name == currentName)

                        Button { test(node) } label: {
                            Group {
                                if testingName == node.name {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "speedometer")
                                        .font(.subheadline)
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTestingAll || selectingName != nil || testingName != nil || node.name == "REJECT")
                        .accessibilityLabel("Test latency for \(node.name)")
                    }
                }
            }
            .navigationTitle(groupName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { testAll() } label: {
                        Group {
                            if isTestingAll {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "speedometer")
                            }
                        }
                        .frame(width: 28, height: 28)
                    }
                    .disabled(isTestingAll || selectingName != nil || testingName != nil || nodes.isEmpty)
                    .accessibilityLabel("Test latency for all nodes")
                }
            }
        }
    }

    private func testAll() {
        isTestingAll = true
        selectionError = nil
        Task {
            do {
                try await onTestAll()
                await MainActor.run { isTestingAll = false }
            } catch {
                await MainActor.run {
                    selectionError = error.localizedDescription
                    isTestingAll = false
                }
            }
        }
    }

    private func test(_ node: ProxyDetail) {
        testingName = node.name
        selectionError = nil
        Task {
            do {
                try await onTest(node.name)
                await MainActor.run { testingName = nil }
            } catch {
                await MainActor.run {
                    selectionError = error.localizedDescription
                    testingName = nil
                }
            }
        }
    }

    private func select(_ node: ProxyDetail) {
        selectingName = node.name
        selectionError = nil
        Task {
            do {
                try await onSelect(node.name)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    selectionError = error.localizedDescription
                    selectingName = nil
                }
            }
        }
    }
}

struct ProxyProviderCard: View {
    @State private var showingNodes = false
    let provider: ProxyProvider

    private var availableCount: Int { provider.proxies.filter(\.alive).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showingNodes = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.tint)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(provider.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(provider.proxies.count) nodes · \(availableCount) available · \(relativeUpdateTime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Text(provider.vehicleType)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            ProxyHealthBar(nodes: provider.proxies)

            if let trafficInfo {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Subscription Usage", systemImage: "chart.bar.fill")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(String(format: "%.1f%%", trafficInfo.percentage))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(trafficColor(trafficInfo.percentage))
                    }

                    GeometryReader { geometry in
                        let progress = min(max(trafficInfo.percentage / 100, 0), 1)
                        Capsule()
                            .fill(trafficColor(trafficInfo.percentage).gradient)
                            .frame(width: geometry.size.width * progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 4)

                    HStack {
                        Text("Used \(trafficInfo.used)")
                        Spacer()
                        Text("Total \(trafficInfo.total)")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            } else {
                Label("Subscription usage unavailable", systemImage: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let expirationDate {
                Label("Expires \(expirationDate)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .sheet(isPresented: $showingNodes) {
            ProviderNodesView(provider: provider)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var trafficInfo: (used: String, total: String, percentage: Double)? {
        guard let info = provider.subscriptionInfo else { return nil }
        let usedBytes = info.upload + info.download
        let percentage = info.total > 0 ? Double(usedBytes) / Double(info.total) * 100 : 0
        return (formatBytes(usedBytes), formatBytes(info.total), percentage)
    }

    private var relativeUpdateTime: String {
        guard let value = provider.updatedAt else { return "Never updated" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return "Update time unknown" }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60: return "Updated just now"
        case ..<3600: return "Updated \(Int(seconds / 60))m ago"
        case ..<86400: return "Updated \(Int(seconds / 3600))h ago"
        default: return "Updated \(Int(seconds / 86400))d ago"
        }
    }

    private var expirationDate: String? {
        guard let expire = provider.subscriptionInfo?.expire, expire > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(expire)).formatted(date: .abbreviated, time: .omitted)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    private func trafficColor(_ percentage: Double) -> Color {
        if percentage < 70 { return .green }
        if percentage < 90 { return .orange }
        return .red
    }
}

struct ProviderNodesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    let provider: ProxyProvider

    private var filteredNodes: [ProxyDetail] {
        guard !searchText.isEmpty else { return provider.proxies }
        return provider.proxies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.type.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredNodes, id: \.name) { node in
                ProxyNodeRow(node: node, isSelected: false, isLoading: false)
                    .padding(.vertical, 3)
            }
            .searchable(text: $searchText, prompt: "Search nodes or protocols")
            .overlay {
                if filteredNodes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle(provider.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(provider.proxies.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ProxyNodeRow: View {
    let node: ProxyDetail
    let isSelected: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(node.alive ? ProxyDelayColor.color(for: node.delay) : .red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(node.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            ProxyDelayBadge(node: node)

            if isLoading {
                ProgressView().controlSize(.small)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ProxyDelayBadge: View {
    let node: ProxyDetail?

    var body: some View {
        Group {
            if let node, node.alive, node.delay > 0 {
                Text("\(node.delay) ms")
                    .foregroundStyle(ProxyDelayColor.color(for: node.delay))
            } else if let node, !node.alive {
                Text("Unavailable").foregroundStyle(.red)
            } else {
                Text("Not Tested").foregroundStyle(.secondary)
            }
        }
        .font(.caption2.monospacedDigit().weight(.medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}

struct ProxyHealthBar: View {
    let nodes: [ProxyDetail]

    private var buckets: [(count: Int, color: Color)] {
        let low = nodes.filter { $0.alive && (1...150).contains($0.delay) }.count
        let medium = nodes.filter { $0.alive && (151...300).contains($0.delay) }.count
        let high = nodes.filter { $0.alive && $0.delay > 300 }.count
        let unavailable = max(0, nodes.count - low - medium - high)
        return [(low, .green), (medium, .orange), (high, .red), (unavailable, .gray)]
            .filter { $0.count > 0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing = CGFloat(max(0, buckets.count - 1)) * 2
            let availableWidth = max(0, geometry.size.width - spacing)
            HStack(spacing: 2) {
                ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                    Capsule()
                        .fill(bucket.color)
                        .frame(width: nodes.isEmpty ? 0 : availableWidth * CGFloat(bucket.count) / CGFloat(nodes.count))
                }
            }
        }
        .frame(height: 5)
        .background(Color(.systemGray5), in: Capsule())
        .accessibilityLabel("Node availability")
    }
}

enum ProxyDelayColor {
    static func color(for delay: Int) -> Color {
        switch delay {
        case 1...150: return .green
        case 151...300: return .orange
        case 301...: return .red
        default: return .secondary
        }
    }
}
