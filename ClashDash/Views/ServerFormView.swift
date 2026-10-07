import SwiftUI

struct ServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appManager = AppManager.shared
    
    @State var server: ClashServer = ClashServer()
    let onSave: (ClashServer) -> Void
    var allowsDemo: Bool = true
      
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

                if allowsDemo && !appManager.servers.contains(where: \.isDemo) {
                    Section {
                        Button {
                            guard appManager.demoServer.status == .ok else { return }
                            appManager.addDemoServer()
                            dismiss()
                        } label: {
                            Label("No server? Try a demo server", systemImage: "play.circle")
                        }
                        .disabled(appManager.demoServer.status != .ok)
                    } footer: {
                        Text(appManager.demoServer.errorMessage ?? "Explore the app with fictional data. No server setup required.")
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
 
