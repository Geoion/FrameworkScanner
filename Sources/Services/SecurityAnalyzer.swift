import Foundation

// MARK: - Security Issue

struct SecurityIssue: Identifiable, Equatable, Codable {
    enum Severity: String, Equatable, Codable {
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
    let recordedAt: String
    /// 受影响的框架标识，与 FrameworkVersionExtractor 的 key 一致（"electron"/"qt"/"python"/"cef"）
    let framework: String

    var severityColor: String {
        switch severity {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }

    // 旧 JSON 文件中没有 framework 字段，解码时默认为 "electron"
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(String.self,   forKey: .id)
        cveId                = try c.decode(String.self,   forKey: .cveId)
        severity             = try c.decode(Severity.self, forKey: .severity)
        summary              = try c.decode(String.self,   forKey: .summary)
        affectedVersionRange = try c.decode(String.self,   forKey: .affectedVersionRange)
        recordedAt           = try c.decode(String.self,   forKey: .recordedAt)
        framework            = try c.decodeIfPresent(String.self, forKey: .framework) ?? "electron"
    }

    enum CodingKeys: String, CodingKey {
        case id, cveId, severity, summary, affectedVersionRange, recordedAt, framework
    }
}

struct SecurityDataStatus: Equatable {
    let version: String
    let lastReviewedAt: String
    let daysSinceReview: Int
    let reminderThresholdDays: Int

    var isStale: Bool {
        daysSinceReview >= reminderThresholdDays
    }

    var daysUntilReminder: Int {
        max(0, reminderThresholdDays - daysSinceReview)
    }
}

// MARK: - Security Analyzer

struct SecurityAnalyzer {
    // SECURITY_RULES_METADATA_START
    private static let securityRulesVersion = "2026.03.27"
    private static let securityRulesLastReviewedAt = "2026-03-27"
    private static let securityRulesReminderThresholdDays = 30
    // SECURITY_RULES_METADATA_END

    // 已知安全的最低 Electron 主版本（Electron 39+ 目前无已知未修复 CVE）
    private static let minSafeElectronMajor = 39

    // 从 Resources/CVE/*.json 加载所有框架的 CVE 数据
    private static let allVulnerabilities: [SecurityIssue] = loadAllCVEs()

    private static func loadAllCVEs() -> [SecurityIssue] {
        guard let cveDir = Bundle.main.resourceURL?.appendingPathComponent("CVE") else {
            return []
        }
        let jsonFiles = (try? FileManager.default.contentsOfDirectory(
            at: cveDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }) ?? []

        let decoder = JSONDecoder()
        return jsonFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }.flatMap { url -> [SecurityIssue] in
            guard let data = try? Data(contentsOf: url),
                  let issues = try? decoder.decode([SecurityIssue].self, from: data) else {
                return []
            }
            return issues
        }
    }

    static func securityDataStatus(referenceDate: Date = Date()) -> SecurityDataStatus {
        let parsed = parseDate(securityRulesLastReviewedAt) ?? .distantPast
        let start = Calendar.current.startOfDay(for: parsed)
        let now = Calendar.current.startOfDay(for: referenceDate)
        let age = max(0, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)

        return SecurityDataStatus(
            version: securityRulesVersion,
            lastReviewedAt: securityRulesLastReviewedAt,
            daysSinceReview: age,
            reminderThresholdDays: securityRulesReminderThresholdDays
        )
    }

    static func analyze(app: AppInfo) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Electron
        if app.detectedFrameworks.contains(.electron),
           let versionStr = app.electronDetail?.electronVersion {
            let comps = versionStr.split(separator: ".").compactMap { Int($0) }
            if let major = comps.first, major < minSafeElectronMajor {
                issues.append(contentsOf: matchedIssues(
                    framework: "electron",
                    major: major,
                    minor: comps.count > 1 ? comps[1] : 0,
                    patch: comps.count > 2 ? comps[2] : 0
                ))
            }
        }

        // Qt
        if app.detectedFrameworks.contains(.qt),
           let versionStr = app.frameworkVersions["qt"] {
            let comps = versionStr.split(separator: ".").compactMap { Int($0) }
            if let major = comps.first {
                issues.append(contentsOf: matchedIssues(
                    framework: "qt",
                    major: major,
                    minor: comps.count > 1 ? comps[1] : 0,
                    patch: comps.count > 2 ? comps[2] : 0
                ))
            }
        }

        // Python
        if app.detectedFrameworks.contains(.python),
           let versionStr = app.frameworkVersions["python"] {
            let comps = versionStr.split(separator: ".").compactMap { Int($0) }
            if let major = comps.first {
                issues.append(contentsOf: matchedIssues(
                    framework: "python",
                    major: major,
                    minor: comps.count > 1 ? comps[1] : 0,
                    patch: comps.count > 2 ? comps[2] : 0
                ))
            }
        }

        return issues
    }

    private static func matchedIssues(framework: String, major: Int, minor: Int, patch: Int) -> [SecurityIssue] {
        allVulnerabilities.filter { issue in
            issue.framework == framework &&
            isVersionAffected(major: major, minor: minor, patch: patch, rangeDescription: issue.affectedVersionRange)
        }
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

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
