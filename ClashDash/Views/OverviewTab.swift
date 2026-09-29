//
//  OverviewTab.swift
//  ClashDash
//
//  Created by Lsong on 1/28/26.
//

import Charts
import SwiftUI

struct OverviewTab: View {
    @ObservedObject var appManager = AppManager.shared
    @StateObject private var monitor = NetworkMonitor()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                
                HStack(spacing: 16) {
                    StatusCard(
                        title: "Total Download",
                        value: monitor.totalDownload,
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    StatusCard(
                        title: "Total Upload",
                        value: monitor.totalUpload,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                }
                
                HStack(spacing: 16) {
                    StatusCard(
                        title: "Connections",
                        value: "\(monitor.activeConnections)",
                        icon: "link.circle.fill",
                        color: .orange
                    )
                    StatusCard(
                        title: "Memory Usage",
                        value: monitor.memoryUsage,
                        icon: "memorychip",
                        color: .purple
                    )
                }
                
                SpeedChartView(
                    title: "Download Speed",
                    icon: "arrow.down.circle",
                    color: .blue,
                    speedHistory: monitor.speedHistory,
                    speed: \.download
                )

                SpeedChartView(
                    title: "Upload Speed",
                    icon: "arrow.up.circle",
                    color: .green,
                    speedHistory: monitor.speedHistory,
                    speed: \.upload
                )
                
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
                    .animation(.smooth(duration: 0.4), value: monitor.memoryHistory.last?.id)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { monitor.startMonitoring(server: appManager.currentServer) }
        .onDisappear { monitor.stopMonitoring() }
        .onChange(of: appManager.currentServer.connectionIdentifier) { _, _ in
            monitor.restartMonitoring(server: appManager.currentServer)
        }
        // .navigationTitle(appManager.appName)
//        .navigationTitle("Overview")
//        .navigationBarTitleDisplayMode(.inline)

    }
}


struct SpeedChartView: View {
    let title: String
    let icon: String
    let color: Color
    let speedHistory: [SpeedRecord]
    let speed: KeyPath<SpeedRecord, Double>
    
    private var maxValue: Double {
        let peak = max(1_000, speedHistory.map { $0[keyPath: speed] }.max() ?? 0)
        let magnitude = pow(10, floor(log10(peak)))
        let normalized = peak / magnitude
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
        
        return magnitude * scale * 1.2
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1_000_000 {
            return String(format: "%.1fM", speed / 1_000_000)
        } else if speed >= 1_000 {
            return String(format: "%.0fK", speed / 1_000)
        } else {
            return String(format: "%.0f", speed)
        }
    }
    
    var body: some View {
        ChartCard(title: title, icon: icon) {
            Chart {
                ForEach(speedHistory) { record in
                    AreaMark(
                        x: .value("Time", record.timestamp),
                        yStart: .value("Speed", 0),
                        yEnd: .value("Speed", record[keyPath: speed])
                    )
                    .foregroundStyle(color.opacity(0.12))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", record.timestamp),
                        y: .value("Speed", record[keyPath: speed])
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(preset: .extended, position: .leading) { value in
                    if let speed = value.as(Double.self) {
                        AxisGridLine()
                        AxisValueLabel(horizontalSpacing: 0) {
                            Text(formatSpeed(speed))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxValue)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .animation(.smooth(duration: 0.4), value: speedHistory.last?.id)
        }
    }
}
