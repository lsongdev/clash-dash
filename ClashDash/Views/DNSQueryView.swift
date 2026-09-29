import SwiftUI

struct DNSQueryView: View {
    let server: ClashServer
    @StateObject private var viewModel = DNSQueryViewModel()
    @State private var domainName = ""
    @State private var selectedType = "A"
    
    let queryTypes = ["A", "AAAA", "MX"]
    
    var body: some View {
        Form {
            Section {
                TextField("Enter a domain", text: $domainName)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                
                Picker("Record Type", selection: $selectedType) {
                    ForEach(queryTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                
                Button("Query") {
                    viewModel.queryDNS(server: server, domain: domainName, type: selectedType)
                }
                .disabled(domainName.isEmpty)
            } header: {
                Text("DNS Lookup")
            } footer: {
                Text("Supports A, AAAA, and MX records")
            }
            
            if !viewModel.results.isEmpty {
                Section("Results") {
                    ForEach(viewModel.results, id: \.self) { result in
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("DNS Lookup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
