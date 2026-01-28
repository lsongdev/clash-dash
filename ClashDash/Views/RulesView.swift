import SwiftUI

struct RulesView: View {
    @StateObject private var viewModel: RulesViewModel
    
    let server: ClashServer
    
    init(server: ClashServer) {
        self.server = server
        _viewModel = StateObject(wrappedValue: RulesViewModel(server: server))
    }
    
    var body: some View {
        NavigationStack {
            List(viewModel.rules) { rule in
                ruleRowView(rule: rule)
            }
            
            .refreshable {
                await viewModel.fetchData()
            }
            .navigationTitle("Rules")
            // .navigationBarTitleDisplayMode(.inline)
        }
        
        
    }
    func ruleRowView(rule: RulesViewModel.Rule) -> some View{
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
}
