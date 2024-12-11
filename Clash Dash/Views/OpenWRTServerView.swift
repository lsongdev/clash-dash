import SwiftUI

struct OpenWRTServerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServerViewModel
    
    var server: ClashServer? // 如果是编辑模式，这个值会被设置
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var useSSL: Bool = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage: String = ""
    
    private var isEditMode: Bool { server != nil }
    
    init(viewModel: ServerViewModel, server: ClashServer? = nil) {
        self.viewModel = viewModel
        self.server = server
        
        if let server = server {
            _name = State(initialValue: server.name)
            _host = State(initialValue: server.url)
            _port = State(initialValue: server.openWRTPort ?? "")
            _useSSL = State(initialValue: server.useSSL)
            _username = State(initialValue: server.openWRTUsername ?? "")
            _password = State(initialValue: server.openWRTPassword ?? "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器信息")) {
                    TextField("名称", text: $name)
                        .textContentType(.name)
                    
                    TextField("服务器地址", text: $host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                    
                    Toggle("使用 HTTPS", isOn: $useSSL)
                }
                
                Section(header: Text("登录信息")) {
                    TextField("用户名", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    SecureField("密码", text: $password)
                        .textContentType(.password)
                }
                
                if isEditMode {
                    Section {
                        Button(role: .destructive) {
                            viewModel.deleteServer(server!)
                            dismiss()
                        } label: {
                            Text("删除服务器")
                        }
                    }
                }
            }
            .navigationTitle(isEditMode ? "编辑服务器" : "添加 OpenWRT 服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "保存" : "添加") {
                        saveServer()
                    }
                    .disabled(!isValid)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !host.isEmpty && !port.isEmpty &&
        !username.isEmpty && !password.isEmpty
    }
    
    private func saveServer() {
        isLoading = true
        
        Task {
            do {
                let cleanHost = host.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
                
                var testServer = ClashServer(
                    id: server?.id ?? UUID(),
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: cleanHost,
                    port: "",
                    secret: "",
                    status: .unknown,
                    version: nil,
                    useSSL: useSSL,
                    source: .openWRT
                )
                
                // 设置 OpenWRT 相关信息
                testServer.openWRTUsername = username
                testServer.openWRTPassword = password
                testServer.openWRTPort = port
                
                // 验证连接并获取 Clash 信息
                let status = try await viewModel.validateOpenWRTServer(testServer, username: username, password: password)
                
                // 更新服务器信息
                testServer.url = status.daip
                testServer.port = status.cnPort
                testServer.secret = status.dase
                testServer.useSSL = status.dbForwardSSL == "1"
                
                if isEditMode {
                    viewModel.updateServer(testServer)
                } else {
                    viewModel.addServer(testServer)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
} 