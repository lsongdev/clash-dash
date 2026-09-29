import SwiftUI

struct ServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var server: ClashServer = ClashServer()
    let onSave: (ClashServer) -> Void
      
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") {
                    TextField("Name (optional)", text: $server.name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Server Address", text: $server.host)
                        .textInputAutocapitalization(.never)
                    TextField("Port", text: $server.port)
                        .keyboardType(.numberPad)
                    TextField("Secret", text: $server.secret)
                        .textInputAutocapitalization(.never)
                    
                    Toggle(isOn: $server.useSSL) {
                        Label {
                            Text("Use HTTPS")
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
            server.name = server.name.trimmingCharacters(in: .whitespacesAndNewlines)
            server.host = server.host
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            server.port = server.port.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(server)
            dismiss()
        }
        .disabled(!server.isValid)
    }
}
 
