import SwiftUI

struct ServerListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appManager = AppManager.shared
    @State private var showingAddSheet = false
    @State private var editingServer: ClashServer?
    
    var onSelect: ((ClashServer) -> Void)?
    
    var body: some View {
        NavigationStack {
            
            if appManager.servers.isEmpty {
                emptyView()
            }
            
            List(appManager.servers) { server in
                ServerRowView(
                    server: server,
                    isSelected: appManager.currentServer.id == server.id
                )
                .onTapGesture {
                    onSelect?(server)
                    dismiss()
                }
                .contextMenu {
                    editButton(for: server)
                    deleteButton(for: server)
                }
                
            }
            .navigationTitle("Servers")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: addButton)
            .navigationDestination(isPresented: $showingAddSheet) {
                ServerFormView() { server in
                    appManager.addServer(server)
                }
            }
            .navigationDestination(item: $editingServer) { server in
                ServerFormView(server: server) { updatedServer in
                    appManager.updateServer(updatedServer)
                }
            }
            
            .refreshable {
                await appManager.checkAllServersStatus()
            }
            .alert("连接错误", isPresented: $appManager.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                if let details = appManager.errorDetails {
                    Text("\(appManager.errorMessage ?? "")\n\n\(details)")
                } else {
                    Text(appManager.errorMessage ?? "")
                }
            }
        }
    }
    
    var addButton: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            Image(systemName: "plus")
        }
    }
    
    private func deleteButton(for server: ClashServer) -> some View {
        Button(role: .destructive) {
            appManager.deleteServer(server)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func editButton(for server: ClashServer) -> some View {
        Button {
            editingServer = server
        } label: {
            Label("Edit", systemImage: "pencil")
        }
    }
    func emptyView() -> some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "server.rack")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 10)
            
            Text("No servers")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap [+] to add server")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                showingAddSheet = true
            }) {
                Text("Add Server")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 160, height: 44)
                    .background(Color.blue)
                    .cornerRadius(22)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ServerRowView: View {
    let server: ClashServer
    let isSelected: Bool
    
    private var versionDisplay: String {
        guard let version = server.version else { return "" }
        return version.count > 15 ? String(version.prefix(15)) + "..." : version
    }
    
    private var statusIcon: String {
        switch server.status {
        case .ok: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .unauthorized: return "lock.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 状态指示器
            ZStack {
                Circle()
                    .fill(server.status.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if isSelected {
                    Image(systemName: statusIcon)
                        .foregroundColor(server.status.color)
                } else {
                    Circle()
                        .fill(server.status.color)
                        .frame(width: 20, height: 20)
                }
                
                
            }
            
            // 服务器信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(server.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if server.isQuickLaunch {
                        Image(systemName: "bolt.circle.fill")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                    }
                    
                    
                }
                
               if let errorMessage = server.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(server.status.color)
                        .lineLimit(1)
                }
            }
        }
    }
}

