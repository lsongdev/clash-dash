//
//  ServerPickerView.swift
//  ClashDash
//
//  Created by Lsong on 1/28/26.
//

import SwiftUI

struct ServerPickerView: View {
    @State private var showServerList = false
    @ObservedObject var appManager = AppManager.shared
    var server: ClashServer { appManager.currentServer }

    var body: some View {
        Button {
            showServerList = true
        } label: {
            HStack(spacing: 6) {
                StatusSelectionIndicator(
                    statusColor: server.status.color,
                    isSelected: !appManager.servers.isEmpty,
                    isChecking: appManager.isChecking(server)
                )
                Text(appManager.servers.isEmpty ? "Select Server" : server.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appManager.servers.isEmpty ? "Select Server" : "Current Server, \(server.displayName)")
        .accessibilityValue(appManager.isChecking(server) ? "Checking" : server.status.text)
        .sheet(isPresented: $showServerList) {
            ServerListView()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ServerPickerView()
}
