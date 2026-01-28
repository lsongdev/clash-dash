//
//  OverviewTab.swift
//  ClashDash
//
//  Created by Lsong on 1/28/26.
//

import Charts
import SwiftUI

struct OverviewTab: View {
    let server: ClashServer
    @StateObject private var monitor = NetworkMonitor()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear
                        .frame(height: 8)
                    // 速度卡片
                    HStack(spacing: 16) {
                        StatusCard(
                            title: "Download",
                            value: monitor.downloadSpeed,
                            icon: "arrow.down.circle",
                            color: .blue
                        )
                        StatusCard(
                            title: "Upload",
                            value: monitor.uploadSpeed,
                            icon: "arrow.up.circle",
                            color: .green
                        )
                    }
                    
                    // 总流量卡片
                    HStack(spacing: 16) {
                        StatusCard(
                            title: "下载总量",
                            value: monitor.totalDownload,
                            icon: "arrow.down.circle.fill",
                            color: .blue
                        )
                        StatusCard(
                            title: "上传总量",
                            value: monitor.totalUpload,
                            icon: "arrow.up.circle.fill",
                            color: .green
                        )
                    }
                    
                    // 状态卡片
                    HStack(spacing: 16) {
                        StatusCard(
                            title: "活动连接",
                            value: "\(monitor.activeConnections)",
                            icon: "link.circle.fill",
                            color: .orange
                        )
                        StatusCard(
                            title: "内存使用",
                            value: monitor.memoryUsage,
                            icon: "memorychip",
                            color: .purple
                        )
                    }
                    
                    // 速率图表
                    SpeedChartView(speedHistory: monitor.speedHistory)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // 只在 Meta 服务器上显示内存图表
                    if server.serverType == .meta {
                        ChartCard(title: "Memory Usage", icon: "memorychip") {
                            Chart(monitor.memoryHistory) { record in
                                AreaMark(
                                    x: .value("Time", record.timestamp),
                                    y: .value("Memory", record.usage)
                                )
                                .foregroundStyle(.purple.opacity(0.3))
                                
                                LineMark(
                                    x: .value("Time", record.timestamp),
                                    y: .value("Memory", record.usage)
                                )
                                .foregroundStyle(.purple)
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    if let memory = value.as(Double.self) {
                                        AxisGridLine()
                                        AxisValueLabel {
                                            Text("\(Int(memory)) MB")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 3))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear { monitor.startMonitoring(server: server) }
            .onDisappear { monitor.stopMonitoring() }
            .navigationTitle("Overview")
            // .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// 更新速率图表组件
struct SpeedChartView: View {
    let speedHistory: [SpeedRecord]
    
    private var maxValue: Double {
        // 获取当前数据中的最大值
        let maxUpload = speedHistory.map { $0.upload }.max() ?? 0
        let maxDownload = speedHistory.map { $0.download }.max() ?? 0
        let currentMax = max(maxUpload, maxDownload)
        
        // 如果没有数据或数据��小，使用最小刻度
        if currentMax < 100_000 { // 小于 100KB/s
            return 100_000 // 100KB/s
        }
        
        // 计算合适的刻度值
        let magnitude = pow(10, floor(log10(currentMax)))
        let normalized = currentMax / magnitude
        
        // 选择合适的刻度倍数：1, 2, 5, 10
        let scale: Double
        if normalized <= 1 {
            scale = 1
        } else if normalized <= 2 {
            scale = 2
        } else if normalized <= 5 {
            scale = 5
        } else {
            scale = 10
        }
        
        // 计算最终的最大值，并留出一些余量（120%）
        return magnitude * scale * 1.2
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1_000_000 {
            return String(format: "%.1f MB/s", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.1f KB/s", speed / 1_000)
        } else {
            return String(format: "%.0f B/s", speed)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Traffic")
                    .font(.headline)
            }
            
            Chart {
                // 添加预设的网格线和标签
                ForEach(Array(stride(from: 0, to: maxValue, by: maxValue/4)), id: \.self) { value in
                    RuleMark(
                        y: .value("Speed", value)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.gray.opacity(0.1))
                }
                
                // 上传数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.upload),
                        series: .value("Type", "Upload")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.upload),
                        series: .value("Type", "Upload")
                    )
                    .foregroundStyle(.green.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                
                // 下载数据
                ForEach(speedHistory) { record in
                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record.download),
                        series: .value("Type", "Download")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record.download),
                        series: .value("Type", "Download")
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(preset: .extended, position: .leading) { value in
                    if let speed = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(horizontalSpacing: 0) {
                            Text(formatSpeed(speed))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            
            // 图例
            HStack {
                Label("Download", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                Label("Upload", systemImage: "circle.fill")
                    .foregroundColor(.green)
            }
            .font(.caption)
        }
    }
}
