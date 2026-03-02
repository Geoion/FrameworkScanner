import Foundation

// MARK: - Security Issue

struct SecurityIssue: Identifiable, Equatable {
    enum Severity: String, Equatable {
        case critical = "critical"
        case high = "high"
        case medium = "medium"
        case low = "low"
    }

    let id: String
    let cveId: String
    let severity: Severity
    let summary: String
    let affectedVersionRange: String

    var severityColor: String {
        switch severity {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}

// MARK: - Security Analyzer

struct SecurityAnalyzer {

    // Electron 已知 CVE 列表（版本号 < minSafeVersion 的均受影响）
    // 数据来源：https://www.electronjs.org/docs/latest/tutorial/security
    private static let electronVulnerabilities: [SecurityIssue] = [
        SecurityIssue(
            id: "CVE-2023-44402",
            cveId: "CVE-2023-44402",
            severity: .high,
            summary: "Context Isolation bypass via window.open",
            affectedVersionRange: "< 27.1.0, < 26.6.0, < 25.9.7"
        ),
        SecurityIssue(
            id: "CVE-2023-39956",
            cveId: "CVE-2023-39956",
            severity: .high,
            summary: "Renderer process sandbox escape",
            affectedVersionRange: "< 26.2.1, < 25.8.1, < 24.8.3"
        ),
        SecurityIssue(
            id: "CVE-2023-29198",
            cveId: "CVE-2023-29198",
            severity: .critical,
            summary: "Out-of-bounds write in V8 (Chromium)",
            affectedVersionRange: "< 25.0.0"
        ),
        SecurityIssue(
            id: "CVE-2022-29247",
            cveId: "CVE-2022-29247",
            severity: .high,
            summary: "Protocol handler allows loading arbitrary code",
            affectedVersionRange: "< 19.0.0, < 18.3.1, < 17.4.1"
        ),
        SecurityIssue(
            id: "CVE-2022-21718",
            cveId: "CVE-2022-21718",
            severity: .medium,
            summary: "Arbitrary file read via custom protocol handler",
            affectedVersionRange: "< 17.0.0, < 16.0.6, < 15.3.5"
        ),
        SecurityIssue(
            id: "CVE-2021-39184",
            cveId: "CVE-2021-39184",
            severity: .high,
            summary: "Context Isolation bypass via window.open",
            affectedVersionRange: "< 15.0.0, < 14.1.0, < 13.3.0"
        ),
        SecurityIssue(
            id: "CVE-2020-15215",
            cveId: "CVE-2020-15215",
            severity: .critical,
            summary: "Remote code execution via nativeWindowOpen",
            affectedVersionRange: "< 11.0.0, < 10.1.2, < 9.3.3"
        ),
    ]

    // 已知安全的最低 Electron 主版本
    private static let minSafeElectronMajor = 28

    static func analyze(app: AppInfo) -> [SecurityIssue] {
        guard app.frameworkType == .electron,
              let detail = app.electronDetail,
              let versionStr = detail.electronVersion else {
            return []
        }

        let components = versionStr.split(separator: ".").compactMap { Int($0) }
        guard let major = components.first else { return [] }

        var issues: [SecurityIssue] = []

        // 检查是否低于最低安全主版本
        if major < minSafeElectronMajor {
            let matchedIssues = electronVulnerabilities.filter { issue in
                isVersionAffected(major: major, minor: components.count > 1 ? components[1] : 0, patch: components.count > 2 ? components[2] : 0, rangeDescription: issue.affectedVersionRange)
            }
            issues.append(contentsOf: matchedIssues)
        }

        return issues
    }

    static func highestSeverity(issues: [SecurityIssue]) -> SecurityIssue.Severity? {
        if issues.contains(where: { $0.severity == .critical }) { return .critical }
        if issues.contains(where: { $0.severity == .high }) { return .high }
        if issues.contains(where: { $0.severity == .medium }) { return .medium }
        if issues.contains(where: { $0.severity == .low }) { return .low }
        return nil
    }

    // 简单版本范围解析：检查 "< X.Y.Z" 格式
    private static func isVersionAffected(major: Int, minor: Int, patch: Int, rangeDescription: String) -> Bool {
        let parts = rangeDescription.components(separatedBy: ", ")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("< ") {
                let versionPart = String(trimmed.dropFirst(2))
                let vComponents = versionPart.split(separator: ".").compactMap { Int($0) }
                guard vComponents.count >= 1 else { continue }
                let limitMajor = vComponents[0]
                let limitMinor = vComponents.count > 1 ? vComponents[1] : 0
                let limitPatch = vComponents.count > 2 ? vComponents[2] : 0

                let current = major * 10000 + minor * 100 + patch
                let limit = limitMajor * 10000 + limitMinor * 100 + limitPatch
                if current < limit { return true }
            }
        }
        return false
    }
}
