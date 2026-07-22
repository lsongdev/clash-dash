import SwiftUI

struct RulesTab: View {
    @ObservedObject var appManager = AppManager.shared
    // @StateObject private var viewModel: RulesViewModel
    
    private var server: ClashServer { appManager.currentServer }
    
    @State var rules: [Rule] = []
    @State var providers: [RuleProvider] = []
    
    var body: some View {
        List {
            Section("Rules") {
                ForEach(rules) { rule in
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
            return
        }
        do {
            async let fetchedRules = appManager.api.fetchRules(server: requestedServer)
            async let fetchedProviders = appManager.api.fetchRuleProviders(server: requestedServer)
            let (newRules, newProviders) = try await (fetchedRules, fetchedProviders)
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            rules = newRules
            providers = newProviders
        } catch is CancellationError {
            // 切换服务器时忽略旧请求结果。
        } catch {
            guard appManager.currentServer.connectionIdentifier == requestedServer.connectionIdentifier else { return }
            rules = []
            providers = []
            print(error)
        }
    }
}
