import SwiftUI

struct RulesTab: View {
    @ObservedObject var appManager = AppManager.shared
    // @StateObject private var viewModel: RulesViewModel
    
    private var server: ClashServer { appManager.currentServer }
    
    @State var rules: [Rule] = []
    @State var providers: [RuleProvider] = []
    @State private var loadError: String?
    
    var body: some View {
        List {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Section("Rules") {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    ruleRowView(rule: rule)
                }
            }
            
            Section("Providers") {
                ForEach(providers) { provider in 
                    HStack {
                        Text(provider.name)
                        Spacer()
                        Text("\(provider.ruleCount)")
                    }
                }
            }
            
        }
        .buttonStyle(PlainButtonStyle())
        .task(id: server.connectionIdentifier) {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
    func ruleRowView(rule: Rule) -> some View{
        HStack(alignment: .center) {
            Image(systemName: "arrow.turn.down.right")
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(rule.type)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(rule.payload)
            }
            Spacer()
            Text(rule.proxy)
        }
    }
    func loadData() async {
        let requestedServer = server
        guard requestedServer.isValid else {
            rules = []
            providers = []
            loadError = "Select a valid server first."
            return
        }
        rules = []
        providers = []
        loadError = nil
        var errors: [String] = []
        do {
            let newRules = try await appManager.api.fetchRules(server: requestedServer)
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            rules = newRules
        } catch is CancellationError {
            return
        } catch {
            errors.append("Rules: \(error.localizedDescription)")
        }
        do {
            let newProviders = try await appManager.api.fetchRuleProviders(server: requestedServer)
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            providers = newProviders
        } catch is CancellationError {
            return
        } catch {
            errors.append("Rule providers: \(error.localizedDescription)")
        }
        guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
        loadError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}
