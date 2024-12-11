import SwiftUI

// 基础的规则单元格
class RuleCell: UITableViewCell {
    private let payloadLabel = UILabel()
    private let proxyLabel = UILabel()
    private let typeLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let topStack = UIStackView(arrangedSubviews: [payloadLabel, proxyLabel])
        topStack.distribution = .equalSpacing
        topStack.spacing = 8
        
        let mainStack = UIStackView(arrangedSubviews: [topStack, typeLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 4
        
        contentView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        payloadLabel.font = .systemFont(ofSize: 15)
        proxyLabel.font = .systemFont(ofSize: 13)
        typeLabel.font = .systemFont(ofSize: 13)
        
        proxyLabel.textColor = .systemBlue
        typeLabel.textColor = .secondaryLabel
        
        proxyLabel.textAlignment = .right
        proxyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        payloadLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    
    func configure(with rule: RulesViewModel.Rule) {
        payloadLabel.text = rule.payload == "" ? "-" : rule.payload
        proxyLabel.text = rule.proxy
        typeLabel.text = rule.type
    }
}

class RuleWithProviderCell: UITableViewCell {
    private let payloadLabel = UILabel()
    private let proxyLabel = UILabel()
    private let typeLabel = UILabel()
    private let providerInfoLabel = UILabel()
    private let refreshButton = UIButton()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let topStack = UIStackView(arrangedSubviews: [payloadLabel, proxyLabel])
        topStack.distribution = .equalSpacing
        topStack.spacing = 8
        
        let bottomStack = UIStackView(arrangedSubviews: [typeLabel, providerInfoLabel, refreshButton])
        bottomStack.spacing = 8
        bottomStack.alignment = .center
        
        let mainStack = UIStackView(arrangedSubviews: [topStack, bottomStack])
        mainStack.axis = .vertical
        mainStack.spacing = 4
        
        contentView.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        payloadLabel.font = .systemFont(ofSize: 15)
        proxyLabel.font = .systemFont(ofSize: 13)
        typeLabel.font = .systemFont(ofSize: 13)
        providerInfoLabel.font = .systemFont(ofSize: 13)
        
        proxyLabel.textColor = .systemBlue
        typeLabel.textColor = .secondaryLabel
        providerInfoLabel.textColor = .secondaryLabel
        
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.tintColor = .systemBlue
        
        proxyLabel.textAlignment = .right
        proxyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        payloadLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    
    func configure(with rule: RulesViewModel.Rule, provider: RulesViewModel.RuleProvider, onRefresh: @escaping () -> Void) {
        payloadLabel.text = rule.payload
        proxyLabel.text = rule.proxy
        typeLabel.text = "\(rule.type) · \(provider.behavior)"
        providerInfoLabel.text = "\(provider.ruleCount)条规则"
        
        refreshButton.removeTarget(nil, action: nil, for: .allEvents)
        refreshButton.addAction(UIAction { _ in
            onRefresh()
        }, for: .touchUpInside)
    }
}

struct RulesView: View {
    let server: ClashServer
    @StateObject private var viewModel: RulesViewModel
    
    init(server: ClashServer) {
        self.server = server
        _viewModel = StateObject(wrappedValue: RulesViewModel(server: server))
    }
    
    var body: some View {
        VStack {
            RulesListRepresentable(
                rules: viewModel.rules,
                providers: viewModel.providers,
                onRefresh: { providerName in
                    Task {
                        await viewModel.refreshProvider(providerName)
                    }
                }
            )
        }
        .refreshable {
            await viewModel.fetchData()
        }
        .navigationTitle("Rules")
    }
}

struct RulesListRepresentable: UIViewRepresentable {
    let rules: [RulesViewModel.Rule]
    let providers: [RulesViewModel.RuleProvider]
    let onRefresh: (String) -> Void
    
    private var items: [RuleListItem] {
        rules.map { rule -> RuleListItem in
            if rule.type == "RuleSet",
               let provider = providers.first(where: { $0.name == rule.payload }) {
                return .ruleWithProvider(rule: rule, provider: provider)
            }
            return .rule(rule: rule)
        }
    }
    
    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.register(RuleCell.self, forCellReuseIdentifier: "RuleCell")
        tableView.register(RuleWithProviderCell.self, forCellReuseIdentifier: "RuleWithProviderCell")
        tableView.showsVerticalScrollIndicator = false
        tableView.estimatedRowHeight = 44
        return tableView
    }
    
    func updateUIView(_ tableView: UITableView, context: Context) {
        context.coordinator.items = items
        context.coordinator.onRefresh = onRefresh
        tableView.reloadData()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, onRefresh: onRefresh)
    }
    
    enum RuleListItem {
        case rule(rule: RulesViewModel.Rule)
        case ruleWithProvider(rule: RulesViewModel.Rule, provider: RulesViewModel.RuleProvider)
    }
    
    class Coordinator: NSObject, UITableViewDelegate, UITableViewDataSource {
        var items: [RuleListItem]
        var onRefresh: (String) -> Void
        
        init(items: [RuleListItem], onRefresh: @escaping (String) -> Void) {
            self.items = items
            self.onRefresh = onRefresh
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return items.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let item = items[indexPath.row]
            
            switch item {
            case .rule(let rule):
                let cell = tableView.dequeueReusableCell(withIdentifier: "RuleCell", for: indexPath) as! RuleCell
                cell.configure(with: rule)
                return cell
                
            case .ruleWithProvider(let rule, let provider):
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "RuleWithProviderCell",
                    for: indexPath
                ) as! RuleWithProviderCell
                cell.configure(with: rule, provider: provider) { [weak self] in
                    self?.onRefresh(provider.name)
                }
                return cell
            }
        }
    }
}

#Preview {
    NavigationStack {
        RulesView(server: ClashServer(name: "测试服务器",
                                    url: "10.1.1.2",
                                    port: "9090",
                                    secret: "123456"))
    }
}
