import WidgetKit
import SwiftUI

struct ClashDashProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClashDashEntry {
        ClashDashEntry(
            date: Date(),
            downloadSpeed: "0 KB/s",
            uploadSpeed: "0 KB/s",
            activeConnections: 0,
            memoryUsage: "0 MB"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ClashDashEntry) -> Void) {
        // 获取实时数据
        let entry = ClashDashEntry(
            date: Date(),
            downloadSpeed: "-- KB/s",
            uploadSpeed: "-- KB/s",
            activeConnections: 0,
            memoryUsage: "-- MB"
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClashDashEntry>) -> Void) {
        // 实现定期更新逻辑
        var entries: [ClashDashEntry] = []
        let currentDate = Date()
        
        // 每5分钟更新一次
        for minuteOffset in 0 ..< 12 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset * 5, to: currentDate)!
            // 这里需要实现从 ClashServer 获取实时数据
            let entry = ClashDashEntry(
                date: entryDate,
                downloadSpeed: "-- KB/s",
                uploadSpeed: "-- KB/s",
                activeConnections: 0,
                memoryUsage: "-- MB"
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct ClashDashEntry: TimelineEntry {
    let date: Date
    let downloadSpeed: String
    let uploadSpeed: String
    let activeConnections: Int
    let memoryUsage: String
}

struct ClashDashWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ClashDashEntry
    
    var smallWidget: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                Text(entry.downloadSpeed)
            }
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.green)
                Text(entry.uploadSpeed)
            }
        }
        .padding()
    }
    
    var mediumWidget: some View {
        HStack(spacing: 16) {
            // 下载速度
            VStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                Text("下载")
                    .font(.caption)
                Text(entry.downloadSpeed)
            }
            
            // 上传速度
            VStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.green)
                Text("上传")
                    .font(.caption)
                Text(entry.uploadSpeed)
            }
            
            // 活动连接
            VStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.orange)
                Text("连接")
                    .font(.caption)
                Text("\(entry.activeConnections)")
            }
        }
        .padding()
    }
    
    var largeWidget: some View {
        VStack(spacing: 16) {
            mediumWidget
            
            // 可以添加更多信息或图表
            // 注意：Widget 中的图表要简化，保持性能
        }
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        case .systemMedium:
            mediumWidget
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        default:
            largeWidget
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
    }
    
    
}



struct ClashDashWidget: Widget {
    private let kind: String = "ClashDashWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: ClashDashProvider()
        ) { entry in
            ClashDashWidgetView(entry: entry)
        }
        .configurationDisplayName("Clash 状态")
        .description("显示 Clash 的实时网络状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}


@main
struct ClashDashWeigetBundle: WidgetBundle {
    var body: some Widget {
        ClashDashWidget()
        ClashDashWeigetControl()
        ClashDashWeigetLiveActivity()
    }
}
