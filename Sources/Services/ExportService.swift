import Foundation

enum ExportService {

    static func generateCSV(from apps: [AppInfo]) -> String {
        var lines: [String] = []
        let header = [
            "Name", "Bundle ID", "Version", "Framework",
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

    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
