import SwiftUI

struct RulesTab: View {
    @ObservedObject var appManager = AppManager.shared
    // @StateObject private var viewModel: RulesViewModel
    
    let server: ClashServer = AppManager.shared.currentServer
    
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
        .task {
            loadData()
        }
        .refreshable {
            loadData()
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
    func loadData() {
        Task {
            rules = try await appManager.api.fetchRules(server: server)
            providers = try await appManager.api.fetchRulesProviders(server: server)
        }
    }
}
