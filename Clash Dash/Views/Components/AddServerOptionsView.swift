import SwiftUI

struct AddServerOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    var onClashControllerSelected: () -> Void
    var onOpenWRTSelected: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    dismiss()
                    onClashControllerSelected()
                }) {
                    Label("Clash 控制器", systemImage: "server.rack")
                }
                
                Button(action: {
                    dismiss()
                    onOpenWRTSelected()
                }) {
                    Label("OpenWRT 服务器", systemImage: "network")
                }
            }
            .navigationTitle("添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
} 