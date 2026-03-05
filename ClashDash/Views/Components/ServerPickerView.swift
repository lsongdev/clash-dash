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
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(server.status.color)
                    .frame(width: 8, height: 8)
                Text(server.displayName)
                    .font(.system(size: 12, weight: .regular))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
            }
            .contentShape(Rectangle())
        }
        .padding(0)
        .buttonStyle(.plain)
        .sheet(isPresented: $showServerList) {
            ServerListView { selectedServer in
                appManager.selectServer(selectedServer)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    ServerPickerView()
}
