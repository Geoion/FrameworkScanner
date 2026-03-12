import Foundation

enum ExportService {

    static func generateCSV(from apps: [AppInfo]) -> String {
        var lines: [String] = []
        let header = [
            "Name", "Bundle ID", "Version", "Framework",
            "Frameworks",
            "Size (bytes)", "Size", "Install Date", "Architecture", "Path"
        ]
        lines.append(header.map { csvEscape($0) }.joined(separator: ","))

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        for app in apps {
            let row: [String] = [
                app.name,
                app.bundleIdentifier,
                app.version,
                app.frameworkType.displayName,
                app.detectedFrameworks.map(\.displayName).joined(separator: "; "),
                String(app.appSize),
                app.formattedSize,
                dateFormatter.string(from: app.installDate),
                app.architecture.rawValue,
                app.path.path
            ]
            lines.append(row.map { csvEscape($0) }.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    static func generateJSON(from apps: [AppInfo]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]

        let items = apps.map { app -> [String: Any] in
            var dict: [String: Any] = [
                "name": app.name,
                "bundleId": app.bundleIdentifier,
                "version": app.version,
                "framework": app.frameworkType.displayName,
                "frameworks": app.detectedFrameworks.map(\.displayName),
                "sizeBytes": app.appSize,
                "size": app.formattedSize,
                "installDate": dateFormatter.string(from: app.installDate),
                "architecture": app.architecture.rawValue,
                "path": app.path.path
            ]
            if let e = app.electronDetail {
                var electron: [String: String] = [:]
                if let v = e.electronVersion { electron["electronVersion"] = v }
                if let v = e.chromiumVersion { electron["chromiumVersion"] = v }
                if let v = e.nodeVersion { electron["nodeVersion"] = v }
                if !electron.isEmpty { dict["electronDetail"] = electron }
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: items,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "[]" }

        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func generateMarkdownReport(from apps: [AppInfo], generatedAt: Date = Date()) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let generated = iso.string(from: generatedAt)

        let total = apps.count
        let riskyApps = apps.filter { !$0.securityIssues.isEmpty }
        let multiFrameworkApps = apps.filter { $0.detectedFrameworks.count > 1 }

        var frameworkCounts: [FrameworkType: Int] = [:]
        for app in apps {
            frameworkCounts[app.frameworkType, default: 0] += 1
        }
        let topFrameworks = frameworkCounts
            .sorted { $0.value > $1.value }
            .prefix(8)

        let largestApps = apps.sorted { $0.appSize > $1.appSize }.prefix(15)

        var lines: [String] = []
        lines.append("# FrameworkScanner Report")
        lines.append("")
        lines.append("- Generated At: \(generated)")
        lines.append("- Total Apps: \(total)")
        lines.append("- Apps With Security Findings: \(riskyApps.count)")
        lines.append("- Multi-Framework Apps: \(multiFrameworkApps.count)")
        lines.append("")

        lines.append("## Framework Distribution (Primary)")
        lines.append("")
        if topFrameworks.isEmpty {
            lines.append("_No data_")
        } else {
            for item in topFrameworks {
                let pct = total > 0 ? Double(item.value) / Double(total) * 100 : 0
                lines.append("- \(item.key.displayName): \(item.value) (\(String(format: "%.1f", pct))%)")
            }
        }
        lines.append("")

        lines.append("## Largest Apps")
        lines.append("")
        lines.append("| Name | Frameworks | Size | Version | Security |")
        lines.append("| --- | --- | ---: | --- | --- |")
        for app in largestApps {
            let frameworks = app.detectedFrameworks.map(\.displayName).joined(separator: ", ")
            let security = app.securityIssues.isEmpty ? "None" : "\(app.securityIssues.count) issue(s)"
            lines.append("| \(mdEscape(app.name)) | \(mdEscape(frameworks)) | \(app.formattedSize) | \(mdEscape(app.version)) | \(mdEscape(security)) |")
        }
        lines.append("")

        lines.append("## Security Findings")
        lines.append("")
        if riskyApps.isEmpty {
            lines.append("_No security findings_")
        } else {
            lines.append("| App | CVE | Severity | Summary |")
            lines.append("| --- | --- | --- | --- |")
            for app in riskyApps {
                for issue in app.securityIssues {
                    lines.append("| \(mdEscape(app.name)) | \(issue.cveId) | \(issue.severity.rawValue) | \(mdEscape(issue.summary)) |")
                }
            }
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func mdEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
