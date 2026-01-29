//
//  AppManager.swift
//
//  Created by Lsong on 1/27/26.
//

import Foundation
import SwiftUI

// MARK: - App Manager
class AppManager: ObservableObject {
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
    @Published var currentServer: ClashServer =  ClashServer(name: "demo", host: "192.168.2.1", port: "7880", secret: "clash@lsong.org")
    
    @Published var servers: [ClashServer] = []
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var errorDetails: String?
    
    private static let currentServerKey = "CurrentSelectedServer"
    private static let saveKey = "SavedClashServers"
    
    let api = ClashAPI()
    
    init() {
        loadServers()
        loadCurrentServer()
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
        servers.append(server)
        saveServers()
        Task {
            await checkServerStatus(server)
        }
    }
    
    func updateServer(_ server: ClashServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            saveServers()
        }
    }
    
    func deleteServer(_ server: ClashServer) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }
    
    // MARK: - Server Status Check
    func checkAllServersStatus() async {
        for server in servers {
            await checkServerStatus(server)
        }
    }
    
    private func checkServerStatus(_ server: ClashServer) async {
        do {
            let version = try await api.getVersion(server)
            print(version)
        } catch {
            print(error)
        }
        
//        if let index = servers.firstIndex(where: { $0.id == server.id }) {
//            var updatedServer = server
//            updatedServer.status = status
//            if let version = version {
//                updatedServer.version = version
//            }
//            if let serverType = serverType {
//                updatedServer.serverType = serverType
//            }
//            updatedServer.errorMessage = errorMessage
//            servers[index] = updatedServer
//            saveServers()
//        }
    }
    
    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    // MARK: - Current Server Management
    private func loadCurrentServer() {
        if let data = UserDefaults.standard.data(forKey: Self.currentServerKey),
           let decoded = try? JSONDecoder().decode(ClashServer.self, from: data) {
            currentServer = decoded
        }
    }
    
    func saveCurrentServer(_ server: ClashServer) {
        currentServer = server
        if let encoded = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(encoded, forKey: Self.currentServerKey)
        }
    }
    
    func selectServer(_ server: ClashServer) {
        saveCurrentServer(server)
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
