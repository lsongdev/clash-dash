import SwiftUI

struct LogView: View {
    let server: ClashServer
    @StateObject private var viewModel = LogViewModel()
    @State private var selectedLevel: LogLevel = .info
    
    var body: some View {
        VStack(spacing: 0) {
            // 日志列表
            if viewModel.logs.isEmpty && viewModel.isConnected {
                EmptyStateView(
                    title: "No Logs Yet",
                    systemImage: "doc.text",
                    description: "Waiting for logs…"
                )
                .transition(.opacity)
            } else if !viewModel.isConnected {
                EmptyStateView(
                    title: "Disconnected",
                    systemImage: "wifi.slash",
                    description: "Trying to reconnect…"
                )
                .transition(.opacity)
            } else {
                ScrollView {
                    LazyVStack() {
                        ForEach(viewModel.logs.reversed()) { log in
                            LogRow(log: log)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.connect(to: server)
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}

struct LogRow: View {
    let log: LogMessage
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 头部信息
            HStack(spacing: 8) {
                // 日志类型标签
                HStack(spacing: 4) {
                    Circle()
                        .fill(log.type.color)
                        .frame(width: 8, height: 8)
                    
                    Text(log.type.displayText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(log.type.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(log.type.color.opacity(0.1))
                .cornerRadius(8)
                
                // 时间戳
                Text(Self.timeFormatter.string(from: log.timestamp))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // 日志内容
            Text(log.payload)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}
 
