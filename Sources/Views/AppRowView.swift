import SwiftUI

struct AppRowView: View {
    let app: AppInfo
    @State private var isExpanded = false
    @State private var embeddedFrameworks: [EmbeddedFramework]?
    @State private var appDetail: AppDetail?
    @State private var isLoadingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isExpanded {
                        if embeddedFrameworks == nil {
                            loadFrameworks()
                        }
                        if appDetail == nil && !isLoadingDetail {
                            loadDetail()
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }

            // 使用 VStack + clipped 实现从上往下展开，summaryRow 不会跳动
            VStack(spacing: 0) {
                detailSection
            }
            .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
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

                    if app.isSystemApp {
                        SystemAppLabel()
                    }

                    if app.isFromHomebrew {
                        HomebrewLabel()
                    }
                }

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            FrameworkTag(type: app.frameworkType, electronDetail: app.electronDetail, securityIssues: app.securityIssues)

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

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([app.path])
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
            .frame(width: 20)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.leading, 66)

            HStack(alignment: .top, spacing: 0) {
                // 左侧：内嵌 Framework 列表
                embeddedFrameworksPanel
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .padding(.vertical, 8)

                // 右侧：App 详情（代码签名 + Info.plist）
                appInfoPanel
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    // MARK: - Embedded Frameworks Panel

    private var embeddedFrameworksPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Embedded Frameworks"))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 66)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if let frameworks = embeddedFrameworks {
                if frameworks.isEmpty {
                    Text(L("No embedded frameworks"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 66)
                        .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(frameworks) { fw in
                            frameworkRow(fw)
                        }
                    }
                    .padding(.bottom, 4)
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, 66)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - App Info Panel

    private var appInfoPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 安全问题
            if !app.securityIssues.isEmpty {
                securitySection
            }

            // 代码签名
            codeSignSection

            // Info.plist 关键字段
            plistSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var securitySection: some View {
        DetailSectionHeader(title: L("Security Issues"))

        ForEach(app.securityIssues) { issue in
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(severityColor(issue.severity))
                VStack(alignment: .leading, spacing: 1) {
                    Text(issue.cveId)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(severityColor(issue.severity))
                    Text(issue.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }

        Divider().padding(.vertical, 6)
    }

    @ViewBuilder
    private var codeSignSection: some View {
        DetailSectionHeader(title: L("Code Signing"))

        if let detail = appDetail {
            if let cs = detail.codeSign {
                DetailRow(key: L("Status"), value: cs.status)
                if let team = cs.teamIdentifier {
                    DetailRow(key: L("Team ID"), value: team)
                }
                if let auth = cs.authority {
                    DetailRow(key: L("Authority"), value: auth)
                }
                DetailRow(key: L("Notarized"), value: cs.isNotarized ? "✓" : "–")
            } else {
                Text(L("Not Signed"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            ProgressView()
                .scaleEffect(0.5)
                .frame(height: 16)
        }

        Divider().padding(.vertical, 6)
    }

    @ViewBuilder
    private var plistSection: some View {
        DetailSectionHeader(title: "Info.plist")

        if let detail = appDetail {
            ForEach(detail.infoPlistEntries, id: \.key) { entry in
                DetailRow(key: entry.key, value: entry.value)
            }
        } else {
            ProgressView()
                .scaleEffect(0.5)
                .frame(height: 16)
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

    private func severityColor(_ severity: SecurityIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private func loadFrameworks() {
        Task.detached(priority: .userInitiated) {
            let frameworks = EmbeddedFrameworkScanner.scan(appURL: app.path)
            await MainActor.run {
                embeddedFrameworks = frameworks
            }
        }
    }

    private func loadDetail() {
        isLoadingDetail = true
        Task.detached(priority: .userInitiated) {
            let detail = await AppDetailService.load(app: app)
            await MainActor.run {
                appDetail = detail
                isLoadingDetail = false
            }
        }
    }
}

// MARK: - Detail Row Components

struct DetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.bottom, 3)
    }
}

struct DetailRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(key)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 90, alignment: .trailing)
                .lineLimit(1)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - System App Label

struct SystemAppLabel: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "apple.logo")
                .font(.system(size: 8))
            Text("System")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(Color.secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Homebrew Label

struct HomebrewLabel: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "mug.fill")
                .font(.system(size: 8))
            Text("Homebrew")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(Color(red: 0.86, green: 0.55, blue: 0.18))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Color(red: 0.86, green: 0.55, blue: 0.18).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 3)
        )
    }
}

// MARK: - Framework Tag

struct FrameworkTag: View {
    let type: FrameworkType
    let electronDetail: ElectronDetail?
    var securityIssues: [SecurityIssue] = []

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if let severity = SecurityAnalyzer.highestSeverity(issues: securityIssues) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(severityColor(severity))
                }
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
        if let severity = SecurityAnalyzer.highestSeverity(issues: securityIssues) {
            return severityColor(severity).opacity(0.15)
        }
        return type.isElectron ? .orange.opacity(0.2) : .secondary.opacity(0.12)
    }

    private func severityColor(_ severity: SecurityIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
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
