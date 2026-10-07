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
            Group {
                if appManager.availableServers.isEmpty {
                    Label("Add Server", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.medium))
                } else {
                    HStack(spacing: 6) {
                        if appManager.isChecking(server) {
                            ProgressView()
                                .controlSize(.mini)
                                .frame(width: 8, height: 8)
                        } else {
                            Circle()
                                .fill(server.status.color)
                                .frame(width: 8, height: 8)
                        }
                        Text(server.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current Server, \(server.displayName)")
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
