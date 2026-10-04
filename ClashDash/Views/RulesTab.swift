import SwiftUI

struct RulesTab: View {
    @ObservedObject private var appManager = AppManager.shared

    private var server: ClashServer { appManager.currentServer }

    @State private var rules: [Rule] = []
    @State private var providers: [RuleProvider] = []
    @State private var updatingRuleIDs: Set<Int> = []
    @State private var refreshingProviderNames: Set<String> = []
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var searchText = ""

    private var filteredRules: [Rule] {
        guard !searchText.isEmpty else { return rules }
        return rules.filter {
            $0.type.localizedCaseInsensitiveContains(searchText)
                || $0.payload.localizedCaseInsensitiveContains(searchText)
                || $0.proxy.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredProviders: [RuleProvider] {
        guard !searchText.isEmpty else { return providers }
        return providers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.behavior.localizedCaseInsensitiveContains(searchText)
                || $0.vehicleType.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if isLoading && rules.isEmpty && providers.isEmpty {
                ProgressView("Loading rules…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError, rules.isEmpty && providers.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Rules", systemImage: "network.slash")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Retry") { Task { await loadData(showLoading: true) } }
                }
            } else if rules.isEmpty && providers.isEmpty {
                ContentUnavailableView(
                    "No Rules",
                    systemImage: "ruler",
                    description: Text("This server returned no rules or rule providers.")
                )
            } else {
                ruleList
            }
        }
        .background(Color(.systemGroupedBackground))
        .task(id: server.connectionIdentifier) { await loadData(showLoading: true) }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ruleList: some View {
        List {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .listRowBackground(Color.red.opacity(0.08))
            }

            if !filteredRules.isEmpty {
                Section("Rules · \(filteredRules.count)") {
                    ForEach(filteredRules) { rule in
                        RuleCard(
                            rule: rule,
                            isUpdating: updatingRuleIDs.contains(rule.id),
                            isEnabled: ruleEnabledBinding(rule)
                        )
                        .modifier(RulesCardStyle())
                    }
                }
            }

            if !filteredProviders.isEmpty {
                Section("Rule Providers · \(filteredProviders.count)") {
                    ForEach(filteredProviders) { provider in
                        RuleProviderCard(
                            provider: provider,
                            isRefreshing: refreshingProviderNames.contains(provider.name),
                            onRefresh: { Task { await refreshProvider(provider) } }
                        )
                        .modifier(RulesCardStyle())
                    }
                }
            }
        }
        .overlay {
            if !searchText.isEmpty && filteredRules.isEmpty && filteredProviders.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .scrollContentBackground(.hidden)
        .buttonStyle(.plain)
        .searchable(text: $searchText, prompt: "Search rules or providers")
        .refreshable { await loadData() }
    }

    private func ruleEnabledBinding(_ rule: Rule) -> Binding<Bool> {
        Binding(
            get: { rules.first(where: { $0.id == rule.id }).map { !$0.isDisabled } ?? false },
            set: { enabled in
                Task { @MainActor in await setRule(rule, enabled: enabled) }
            }
        )
    }

    @MainActor
    private func setRule(_ rule: Rule, enabled: Bool) async {
        guard !updatingRuleIDs.contains(rule.id),
              let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }

        let requestedServer = server
        let previousValue = rules[index].isDisabled
        rules[index].isDisabled = !enabled
        updatingRuleIDs.insert(rule.id)
        loadError = nil

        do {
            try await appManager.api.setRuleDisabled(
                server: requestedServer,
                ruleIndex: rule.id,
                disabled: !enabled
            )
        } catch is CancellationError {
            if appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier,
               let currentIndex = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[currentIndex].isDisabled = previousValue
            }
        } catch {
            if appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier,
               let currentIndex = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[currentIndex].isDisabled = previousValue
                loadError = "Rule update: \(error.localizedDescription)"
            }
        }

        if appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier {
            updatingRuleIDs.remove(rule.id)
        }
    }

    @MainActor
    private func refreshProvider(_ provider: RuleProvider) async {
        guard !refreshingProviderNames.contains(provider.name) else { return }
        let requestedServer = server
        refreshingProviderNames.insert(provider.name)
        loadError = nil

        defer {
            if appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier {
                refreshingProviderNames.remove(provider.name)
            }
        }
        do {
            try await appManager.api.refreshRulesProvider(server: requestedServer, name: provider.name)
            let refreshedProviders = try await appManager.api.fetchRuleProviders(server: requestedServer)
            let refreshedRules = try await appManager.api.fetchRules(server: requestedServer)
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            providers = refreshedProviders
            rules = refreshedRules
        } catch is CancellationError {
            return
        } catch {
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            loadError = "Rule provider: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadData(showLoading: Bool = false) async {
        let requestedServer = server
        guard requestedServer.isValid else {
            rules = []
            providers = []
            isLoading = false
            loadError = "Select a valid server first."
            return
        }

        if showLoading {
            isLoading = true
            rules = []
            providers = []
            updatingRuleIDs = []
            refreshingProviderNames = []
            searchText = ""
        }
        defer {
            if appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier {
                isLoading = false
            }
        }
        loadError = nil
        var errors: [String] = []
        var newRules = rules
        var newProviders = providers

        do {
            newRules = try await appManager.api.fetchRules(server: requestedServer)
        } catch is CancellationError {
            return
        } catch {
            errors.append("Rules: \(error.localizedDescription)")
        }

        do {
            newProviders = try await appManager.api.fetchRuleProviders(server: requestedServer)
        } catch is CancellationError {
            return
        } catch {
            errors.append("Rule providers: \(error.localizedDescription)")
        }

        guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
        rules = newRules
        providers = newProviders
        loadError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}

private struct RulesCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct RuleCard: View {
    let rule: Rule
    let isUpdating: Bool
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: rule.isDisabled ? "pause.circle" : ruleIcon)
                    .foregroundStyle(rule.isDisabled ? Color.secondary : Color.accentColor)
                    .frame(width: 22)
                Text(displayPayload)
                    .font(.headline)
                    .foregroundStyle(rule.isDisabled ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(rule.type)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .fixedSize()
                Spacer(minLength: 0)
                Text("#\(rule.id + 1)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityLabel("Rule \(rule.id + 1)")
            }

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.isDisabled ? "Disabled · Routes to" : "Routes to")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(rule.proxy)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(rule.isDisabled ? .secondary : .primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isUpdating {
                    ProgressView().controlSize(.small)
                }
                Toggle("Enable \(rule.type) rule \(rule.id + 1)", isOn: $isEnabled)
                    .labelsHidden()
                    .controlSize(.small)
                    .disabled(isUpdating)
            }
        }
    }

    private var ruleIcon: String {
        let type = rule.type.uppercased().replacingOccurrences(of: "-", with: "")
        if type.contains("DOMAIN") || type == "GEOSITE" { return "globe" }
        if type.contains("IP") || type == "GEOIP" { return "network" }
        if type.contains("PROCESS") { return "app.badge" }
        if type == "RULESET" { return "square.stack.3d.up" }
        if type == "MATCH" || type == "FINAL" { return "arrow.triangle.branch" }
        return "line.3.horizontal.decrease"
    }

    private var displayPayload: String {
        if !rule.payload.isEmpty { return rule.payload }
        return ["MATCH", "FINAL"].contains(rule.type.uppercased()) ? "All traffic" : "Any matching traffic"
    }
}

private struct RuleProviderCard: View {
    let provider: RuleProvider
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                Text(provider.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(provider.vehicleType)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .fixedSize()
                Spacer(minLength: 4)
                Button(action: onRefresh) {
                    Group {
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh \(provider.name) provider")
            }

            HStack(spacing: 10) {
                Image(systemName: behaviorIcon)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rule Behavior")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(behaviorTitle)
                        .font(.subheadline.weight(.medium))
                }
                Spacer(minLength: 4)
                if let format = provider.format, !format.isEmpty {
                    Text(format.uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }

            Divider()

            HStack(spacing: 8) {
                if provider.ruleCount >= 0 {
                    Label("\(provider.ruleCount) rules", systemImage: "list.bullet")
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                Text(updateSummary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var behaviorTitle: String {
        switch provider.behavior.lowercased() {
        case "domain": return "Domain matching"
        case "ipcidr": return "IP range matching"
        case "classical": return "Mixed rule matching"
        default: return provider.behavior.capitalized
        }
    }

    private var behaviorIcon: String {
        switch provider.behavior.lowercased() {
        case "domain": return "globe"
        case "ipcidr": return "network"
        default: return "line.3.horizontal.decrease"
        }
    }

    private var updateSummary: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: provider.updatedAt)
            ?? ISO8601DateFormatter().date(from: provider.updatedAt) else { return "Update time unknown" }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60: return "Updated just now"
        case ..<3600: return "Updated \(Int(seconds / 60))m ago"
        case ..<86400: return "Updated \(Int(seconds / 3600))h ago"
        default: return "Updated \(Int(seconds / 86400))d ago"
        }
    }
}
