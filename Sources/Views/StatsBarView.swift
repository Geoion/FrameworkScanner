import SwiftUI

struct StatsBarView: View {
    @EnvironmentObject private var viewModel: ScannerViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let stats = viewModel.stats

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                StatBadge(
                    label: L("Total"),
                    value: "\(stats.total)",
                    color: .primary
                )

                ForEach(stats.frameworkCounts.prefix(6), id: \.type) { item in
                    StatBadge(
                        label: item.type.displayName,
                        value: "\(item.count) (\(stats.percentage(for: item.type)))",
                        color: item.type == .electron ? .orange : .secondary,
                        bold: item.type == .electron
                    )
                }

                if stats.electronTotalSize > 0 {
                    StatBadge(
                        label: L("Electron Disk"),
                        value: ByteCountFormatter.string(
                            fromByteCount: stats.electronTotalSize,
                            countStyle: .file
                        ),
                        color: .orange
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    var color: Color = .secondary
    var bold: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .fontWeight(bold ? .bold : .medium)
                .foregroundStyle(color)
        }
    }
}
