import SwiftUI

struct ServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var server: ClashServer = ClashServer()
    let onSave: (ClashServer) -> Void
      
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $server.name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("服务器地址", text: $server.host)
                        .textInputAutocapitalization(.never)
                    TextField("端口", text: $server.port)
                        .keyboardType(.numberPad)
                    TextField("密钥", text: $server.secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $server.useSSL) {
                        Label {
                            Text("使用 HTTPS")
                        } icon: {
                            Image(systemName: "lock.fill")
                                .foregroundColor(server.useSSL ? .green : .secondary)
                        }
                    }
                } header: {
                    Text("服务器信息")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("如果服务器启用了 HTTPS，请打开 HTTPS 开关")
                        Text("根据苹果的应用传输安全(App Transport Security, ATS)策略，iOS 应用在与域名通信时必须使用 HTTPS")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Server")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: saveButton)
        }
    }
    var saveButton: some View {
        Button("Save") {
            onSave(server)
            dismiss()
        }
        .disabled(server.isValid)
    }
}
 
