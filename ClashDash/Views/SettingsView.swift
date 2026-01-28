import SwiftUI
import CoreHaptics

struct SettingsView: View {
    @ObservedObject var viewModel: ServerViewModel
    @AppStorage("autoDisconnectOldProxy") private var autoDisconnectOldProxy = false
    @AppStorage("hideUnavailableProxies") private var hideUnavailableProxies = false
    @AppStorage("speedTestURL") private var speedTestURL = "https://www.gstatic.com/generate_204"
    @AppStorage("speedTestTimeout") private var speedTestTimeout = 5000
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack{
            Form {
                Section {
                    Picker("主题", selection: $appTheme) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                }
            }
            
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        
        
    }
}

// 辅助视图组件
struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(subtitle)
                    .caption()
            }
        }
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let message: String
    
    var body: some View {
        Label {
            Text(message)
                .caption()
        } icon: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(.secondary)
            .textCase(nil)
    }
}

// 扩展便捷修饰符
extension View {
    func caption() -> some View {
        self.font(.caption)
            .foregroundColor(.secondary)
    }
}

