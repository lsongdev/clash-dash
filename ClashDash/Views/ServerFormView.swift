import SwiftUI

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    
    @State private var name = ""
    @State private var url = ""
    @State private var port = ""
    @State private var secret = ""
    @State private var useSSL = false
    
    private var isHostname: Bool {
        // 检查 URL 是否是 IP 地址
        let ipPattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
        let ipPredicate = NSPredicate(format: "SELF MATCHES %@", ipPattern)
        return !ipPredicate.evaluate(with: url) && !url.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器地址", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: url) { _ in
                            if isHostname {
                                useSSL = true
                            }
                        }
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("密钥", text: $secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $useSSL) {
                        Label {
                            Text("使用 HTTPS")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(useSSL ? .green : .secondary)
                        }
                    }
                    .disabled(isHostname)
                } header: {
                    Text("服务器信息")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("如果服务器启用了 HTTPS，请打开 HTTPS 开关")
                        if isHostname {
                            Text("根据苹果的应用传输安全(App Transport Security, ATS)策略，iOS 应用在与域名通信时必须使用 HTTPS")
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationTitle("添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let server = ClashServer(
                            name: name,
                            url: url,
                            port: port,
                            secret: secret,
                            useSSL: useSSL
                        )
                        viewModel.addServer(server)
                        dismiss()
                    }
                    .disabled(url.isEmpty || port.isEmpty || secret.isEmpty)
                }
            }
        }
    }
}


struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    let server: ClashServer
    
    @State private var name: String
    @State private var url: String
    @State private var port: String
    @State private var secret: String
    @State private var useSSL: Bool
    
    private var isHostname: Bool {
        // 检查 URL 是否是 IP 地址
        let ipPattern = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
        let ipPredicate = NSPredicate(format: "SELF MATCHES %@", ipPattern)
        return !ipPredicate.evaluate(with: url) && !url.isEmpty
    }
    
    init(viewModel: ServerViewModel, server: ClashServer) {
        self.viewModel = viewModel
        self.server = server
        self._name = State(initialValue: server.name)
        self._url = State(initialValue: server.url)
        self._port = State(initialValue: server.port)
        self._secret = State(initialValue: server.secret)
        self._useSSL = State(initialValue: server.useSSL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name)
                    TextField("服务器地址", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: url) { _ in
                            if isHostname {
                                useSSL = true
                            }
                        }
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    TextField("密钥", text: $secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $useSSL) {
                        Label {
                            Text("使用 HTTPS")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(useSSL ? .green : .secondary)
                        }
                    }
                    .disabled(isHostname)
                } header: {
                    Text("服务器信息")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("如果服务器启用了 HTTPS，请打开 HTTPS 开关")
                        if isHostname {
                            Text("根据苹果的应用传输安全(App Transport Security, ATS)策略，iOS 应用在与域名通信时必须使用 HTTPS")
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationTitle("编辑服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updatedServer = ClashServer(
                            id: server.id,
                            name: name,
                            url: url,
                            port: port,
                            secret: secret,
                            status: server.status,
                            version: server.version,
                            useSSL: useSSL
                        )
                        viewModel.updateServer(updatedServer)
                        dismiss()
                    }
                    .disabled(url.isEmpty || port.isEmpty || secret.isEmpty)
                }
            }
        }
    }
}
