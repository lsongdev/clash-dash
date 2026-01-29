import SwiftUI

struct ServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var server: ClashServer = ClashServer()
    let onSave: (ClashServer) -> Void
      
    var body: some View {
        NavigationStack {
            Form {
                Section("服务器信息") {
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
 
