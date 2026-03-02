import SwiftUI
import Charts

@available(macOS 14.0, *)
struct ChartsWindowView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L("Framework Distribution"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 4)

                frameworkPieSection

                Divider()

                frameworkBarSection

                Divider()

                diskUsageSection
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 500)
    }

    // MARK: - Pie Chart

    private var frameworkPieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Framework Share"))
                .font(.headline)

            let data = viewModel.stats.frameworkCounts
            Chart(data, id: \.type) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Framework", item.type.displayName))
                .cornerRadius(4)
                .annotation(position: .overlay) {
                    if item.count > 0 && Double(item.count) / Double(viewModel.stats.total) > 0.05 {
                        Text("\(item.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
            .chartLegend(position: .trailing, alignment: .center, spacing: 16)
            .frame(height: 260)
        }
    }

    // MARK: - Bar Chart

    private var frameworkBarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("App Count by Framework"))
                .font(.headline)

            let data = viewModel.stats.frameworkCounts
            Chart(data, id: \.type) { item in
                BarMark(
                    x: .value("Framework", item.type.displayName),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(barColor(for: item.type))
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
    }

    // MARK: - Disk Usage Chart

    private var diskUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Disk Usage by Framework"))
                .font(.headline)

            let diskData = diskUsageData()
            if diskData.isEmpty {
                Text(L("No data available"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(diskData, id: \.name) { item in
                    BarMark(
                        x: .value("Size", item.bytes),
                        y: .value("Framework", item.name)
                    )
                    .foregroundStyle(barColor(for: item.frameworkType))
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: max(180, CGFloat(diskData.count) * 36))
            }
        }
    }

    // MARK: - Helpers

    private struct DiskItem {
        let name: String
        let bytes: Int64
        let frameworkType: FrameworkType
    }

    private func diskUsageData() -> [DiskItem] {
        var sizeMap: [FrameworkType: Int64] = [:]
        for app in viewModel.allApps {
            sizeMap[app.frameworkType, default: 0] += app.appSize
        }
        return sizeMap
            .sorted { $0.value > $1.value }
            .map { DiskItem(name: $0.key.displayName, bytes: $0.value, frameworkType: $0.key) }
    }

    private func barColor(for type: FrameworkType) -> Color {
        switch type {
        case .electron: return .orange
        case .swiftUI: return .blue
        case .appKit: return .indigo
        case .catalyst: return .purple
        case .qt: return .green
        case .flutter: return .cyan
        case .tauri: return .teal
        case .javaJVM: return .brown
        case .cef: return .yellow
        case .dotNet: return .pink
        case .unity: return .gray
        case .unreal: return .red
        case .python: return .mint
        case .go: return Color(red: 0.0, green: 0.68, blue: 0.94)
        case .reactNative: return Color(red: 0.35, green: 0.78, blue: 0.98)
        case .capacitor: return Color(red: 0.22, green: 0.60, blue: 0.86)
        case .unknown: return .secondary
        }
    }
}
