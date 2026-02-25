import SwiftUI

struct AppRowView: View {
    let app: AppInfo
    @State private var isExpanded = false
    @State private var embeddedFrameworks: [EmbeddedFramework]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isExpanded && embeddedFrameworks == nil {
                        loadFrameworks()
                    }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }

            detailSection
                .frame(maxHeight: isExpanded ? .none : 0)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10)

            Image(nsImage: app.icon)
                .interpolation(.high)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("v\(app.version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                }

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            FrameworkTag(type: app.frameworkType, electronDetail: app.electronDetail)

            VStack(alignment: .trailing, spacing: 2) {
                Text(app.formattedSize)
                    .font(.caption)
                    .monospacedDigit()

                Text(app.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, alignment: .trailing)

            Text(app.architecture.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .frame(width: 90)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.leading, 66)

            if let frameworks = embeddedFrameworks {
                if frameworks.isEmpty {
                    Text(NSLocalizedString("No embedded frameworks", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 66)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(frameworks) { fw in
                            frameworkRow(fw)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func frameworkRow(_ fw: EmbeddedFramework) -> some View {
        HStack(spacing: 8) {
            Text(fw.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(fw.version)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))

            Text(fw.path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(fw.formattedSize)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, 58)
    }

    private func loadFrameworks() {
        Task.detached(priority: .userInitiated) {
            let frameworks = EmbeddedFrameworkScanner.scan(appURL: app.path)
            await MainActor.run {
                embeddedFrameworks = frameworks
            }
        }
    }
}

// MARK: - Framework Tag

struct FrameworkTag: View {
    let type: FrameworkType
    let electronDetail: ElectronDetail?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: type.symbolName)
                    .font(.caption2)
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tagBackground, in: Capsule())

            if type.isElectron, let detail = electronDetail {
                electronVersionInfo(detail)
            }
        }
        .frame(width: 140, alignment: .trailing)
    }

    private var tagBackground: Color {
        type.isElectron ? .orange.opacity(0.2) : .secondary.opacity(0.12)
    }

    @ViewBuilder
    private func electronVersionInfo(_ detail: ElectronDetail) -> some View {
        HStack(spacing: 6) {
            if let ev = detail.electronVersion {
                Text("e\(ev)")
                    .font(.system(size: 9))
            }
            if let cv = detail.chromiumVersion {
                Text("Cr \(cv)")
                    .font(.system(size: 9))
            }
            if let nv = detail.nodeVersion {
                Text("N \(nv)")
                    .font(.system(size: 9))
            }
        }
        .foregroundStyle(.orange)
    }
}
