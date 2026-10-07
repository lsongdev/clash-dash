import SwiftUI

struct ServerListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appManager = AppManager.shared
    @State private var showingAddSheet = false
    @State private var editingServer: ClashServer?
    
    var onSelect: ((ClashServer) -> Void)?
    
    var body: some View {
        NavigationStack {
            if appManager.availableServers.isEmpty {
                emptyView()
                    .navigationTitle("Servers")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { addButton } }
            } else {
                List(appManager.availableServers) { server in
                    Button {
                        onSelect?(server)
                        appManager.selectServer(server)
                        dismiss()
                    } label: {
                        ServerRowView(
                            server: server,
                            isSelected: appManager.currentServer.id == server.id,
                            isChecking: appManager.isChecking(server)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        deleteButton(for: server)
                        if !server.isDemo {
                            editButton(for: server)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: server)
                        if !server.isDemo {
                            editButton(for: server).tint(.blue)
                        }
                    }
                }
                .navigationTitle("Servers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            Task { await appManager.checkAllServersStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(!appManager.checkingServerIDs.isEmpty)
                        addButton
                    }
                }
                .refreshable {
                    await appManager.checkAllServersStatus()
                }
            }

            Color.clear
                .frame(width: 0, height: 0)
            .navigationDestination(isPresented: $showingAddSheet) {
                ServerFormView() { server in
                    appManager.addServer(server)
                }
            }
            .navigationDestination(item: $editingServer) { server in
                ServerFormView(server: server, onSave: { updatedServer in
                    appManager.updateServer(updatedServer)
                }, allowsDemo: false)
            }
            .alert("Connection Error", isPresented: $appManager.showError) {
                Button("OK", role: .cancel) {}
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
        Button {
            showingAddSheet = true
        } label: {
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
            
            Text("Add a server to get started, or try the local demo.")
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
    let isChecking: Bool
    
    private var versionDisplay: String {
        guard let version = server.version, !version.isEmpty else { return server.status.text }
        return server.isDemo ? "Local only · Safe to explore" : "\(server.status.text) · \(version)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            StatusSelectionIndicator(
                statusColor: server.status.color,
                isSelected: isSelected,
                isChecking: isChecking
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(server.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(server.endpointDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(isChecking ? "Checking connection…" : (server.errorMessage?.isEmpty == false ? server.errorMessage! : versionDisplay))
                    .font(.caption2)
                    .foregroundStyle(server.status == .error || server.status == .unauthorized ? server.status.color : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected, \(server.status.text)" : server.status.text)
    }
}
