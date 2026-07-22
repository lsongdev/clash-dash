//
//  AppManager.swift
//
//  Created by Lsong on 1/27/26.
//

import Foundation
import SwiftUI

// MARK: - App Manager
@MainActor
final class AppManager: ObservableObject {
    // MARK: - 单例
    static let shared = AppManager()
      
    @AppStorage("colorScheme") var colorSchemeMode: ColorSchemeMode = .system
    @AppStorage("appTintColor") var appTintColor: AppTintColor = .orange
    @AppStorage("appFontDesign") var appFontDesign: AppFontDesign = .standard
    @AppStorage("appFontSize") var appFontSize: AppFontSize = .xlarge
    @AppStorage("appFontWidth") var appFontWidth: AppFontWidth = .expanded
    @AppStorage("currentAccountEmail") var currentAccountEmail: String = ""
    
    // MARK: - 发布的状态属性
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Server Management
    @Published private(set) var currentServer = ClashServer()
    
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    @Published private(set) var checkingServerIDs: Set<UUID> = []
    
    private static let currentServerKey = "CurrentSelectedServer"
    private static let currentServerIDKey = "CurrentSelectedServerID"
    private static let saveKey = "SavedClashServers"
    private var statusCheckTokens: [UUID: UUID] = [:]
    
    let api = ClashAPI()
    
    init() {
        loadServers()
        loadCurrentServer()
        Task {
            await checkAllServersStatus()
        }
    }
    
    // MARK: - Server Loading & Saving
    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: Self.saveKey),
           let decoded = try? JSONDecoder().decode([ClashServer].self, from: data) {
            servers = decoded
        }
    }
    
    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }
    
    // MARK: - Server Management
    func addServer(_ server: ClashServer) {
        var newServer = server
        newServer.status = .unknown
        newServer.version = nil
        newServer.errorMessage = nil
        servers.append(newServer)
        saveServers()
        if servers.count == 1 {
            selectServer(newServer)
        } else {
            Task {
                await checkServerStatus(newServer)
            }
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            var updatedServer = server
            updatedServer.status = .unknown
            updatedServer.version = nil
            updatedServer.errorMessage = nil
            servers[index] = updatedServer
            saveServers()
            if currentServer.id == updatedServer.id {
                setCurrentServer(updatedServer)
            }
            Task {
                await checkServerStatus(updatedServer)
            }
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        let deletedIndex = servers.firstIndex(where: { $0.id == server.id })
        servers.removeAll { $0.id == server.id }
        checkingServerIDs.remove(server.id)
        statusCheckTokens.removeValue(forKey: server.id)
        saveServers()

        guard currentServer.id == server.id else { return }
        if servers.isEmpty {
            currentServer = ClashServer()
            clearCurrentServerSelection()
        } else {
            let nextIndex = min(deletedIndex ?? 0, servers.count - 1)
            setCurrentServer(servers[nextIndex])
        }
    }
    
    // MARK: - Server Status Check
    func checkAllServersStatus() async {
        let snapshot = servers
        await withTaskGroup(of: Void.self) { group in
            for server in snapshot {
                group.addTask { [weak self] in
                    await self?.checkServerStatus(server)
                }
            }
        }
    }

    func checkServerStatus(_ server: ClashServer) async {
        guard servers.contains(where: { $0.id == server.id }) else { return }
        let checkToken = UUID()
        statusCheckTokens[server.id] = checkToken
        checkingServerIDs.insert(server.id)
        defer {
            if statusCheckTokens[server.id] == checkToken {
                statusCheckTokens.removeValue(forKey: server.id)
                checkingServerIDs.remove(server.id)
            }
        }

        do {
            let version = try await api.getVersion(server)
            if let index = matchingServerIndex(for: server) {
                servers[index].status = .ok
                servers[index].version = version
                servers[index].errorMessage = nil
                saveServers()
                syncCurrentServerIfNeeded(servers[index])
            }
        } catch {
            if let index = matchingServerIndex(for: server) {
                if case NetworkError.unauthorized = error {
                    servers[index].status = .unauthorized
                } else {
                    servers[index].status = .error
                }
                servers[index].version = nil
                servers[index].errorMessage = error.localizedDescription
                saveServers()
                syncCurrentServerIfNeeded(servers[index])
            }
        }
    }

    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    // MARK: - Current Server Management
    private func loadCurrentServer() {
        let defaults = UserDefaults.standard
        if let idString = defaults.string(forKey: Self.currentServerIDKey),
           let id = UUID(uuidString: idString),
           let selectedServer = servers.first(where: { $0.id == id }) {
            currentServer = selectedServer
            return
        }

        // 兼容旧版本保存的完整服务器对象。
        if let data = defaults.data(forKey: Self.currentServerKey),
           let decoded = try? JSONDecoder().decode(ClashServer.self, from: data),
           let selectedServer = servers.first(where: { $0.id == decoded.id }) {
            currentServer = selectedServer
            persistCurrentServerSelection()
            return
        }

        currentServer = servers.first ?? ClashServer()
        if !servers.isEmpty { persistCurrentServerSelection() }
    }
    
    func selectServer(_ server: ClashServer) {
        guard let selectedServer = servers.first(where: { $0.id == server.id }) else { return }
        guard currentServer.id != selectedServer.id else { return }
        setCurrentServer(selectedServer)
        Task { await checkServerStatus(selectedServer) }
    }

    func isChecking(_ server: ClashServer) -> Bool {
        checkingServerIDs.contains(server.id)
    }

    private func matchingServerIndex(for snapshot: ClashServer) -> Int? {
        servers.firstIndex {
            $0.id == snapshot.id
                && $0.host == snapshot.host
                && $0.port == snapshot.port
                && $0.secret == snapshot.secret
                && $0.useSSL == snapshot.useSSL
        }
    }

    private func syncCurrentServerIfNeeded(_ server: ClashServer) {
        if currentServer.id == server.id {
            currentServer = server
        }
    }

    private func setCurrentServer(_ server: ClashServer) {
        currentServer = server
        persistCurrentServerSelection()
    }

    private func persistCurrentServerSelection() {
        let defaults = UserDefaults.standard
        defaults.set(currentServer.id.uuidString, forKey: Self.currentServerIDKey)
        if let encoded = try? JSONEncoder().encode(currentServer) {
            defaults.set(encoded, forKey: Self.currentServerKey)
        }
    }

    private func clearCurrentServerSelection() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.currentServerIDKey)
        defaults.removeObject(forKey: Self.currentServerKey)
    }
}

extension AppManager {
    var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Cloudflare"
    }
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }
}
