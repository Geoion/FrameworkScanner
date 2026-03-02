import Foundation

struct AppDetail {
    struct CodeSignInfo {
        let status: String
        let teamIdentifier: String?
        let authority: String?
        let isNotarized: Bool
    }

    let codeSign: CodeSignInfo?
    let infoPlistEntries: [(key: String, value: String)]
    let securityIssues: [SecurityIssue]
}

struct AppDetailService {

    static func load(app: AppInfo) async -> AppDetail {
        async let codeSign = fetchCodeSignInfo(appURL: app.path)
        async let plistEntries = fetchInfoPlistEntries(appURL: app.path)

        return AppDetail(
            codeSign: await codeSign,
            infoPlistEntries: await plistEntries,
            securityIssues: app.securityIssues
        )
    }

    // MARK: - Code Signing

    private static func fetchCodeSignInfo(appURL: URL) async -> AppDetail.CodeSignInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", appURL.path]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        // codesign -dv 输出到 stderr
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: errData, encoding: .utf8) ?? ""

        if output.isEmpty { return nil }

        let lines = output.components(separatedBy: "\n")
        var teamID: String?
        var authority: String?
        var isNotarized = false
        var status = "Signed"

        for line in lines {
            if line.hasPrefix("TeamIdentifier=") {
                teamID = String(line.dropFirst("TeamIdentifier=".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Authority=") && authority == nil {
                authority = String(line.dropFirst("Authority=".count)).trimmingCharacters(in: .whitespaces)
            } else if line.contains("notarized") || line.contains("Notarized") {
                isNotarized = true
            }
        }

        if process.terminationStatus != 0 {
            status = "Not Signed"
            teamID = nil
            authority = nil
        }

        return AppDetail.CodeSignInfo(
            status: status,
            teamIdentifier: teamID,
            authority: authority,
            isNotarized: isNotarized
        )
    }

    // MARK: - Info.plist

    private static let displayedPlistKeys: [String] = [
        "CFBundleIdentifier",
        "CFBundleShortVersionString",
        "CFBundleVersion",
        "CFBundleExecutable",
        "LSMinimumSystemVersion",
        "NSHumanReadableCopyright",
        "CFBundleDevelopmentRegion",
        "NSPrincipalClass",
        "LSApplicationCategoryType",
        "CFBundleURLTypes",
        "NSAppTransportSecurity",
    ]

    private static func fetchInfoPlistEntries(appURL: URL) async -> [(key: String, value: String)] {
        let plistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }

        var entries: [(key: String, value: String)] = []
        for key in displayedPlistKeys {
            guard let value = plist[key] else { continue }
            let displayValue = formatPlistValue(value)
            entries.append((key: key, value: displayValue))
        }

        // 补充未在固定列表中但存在的 NS 权限 key
        let permissionKeys = plist.keys.filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") }
        for key in permissionKeys.sorted() {
            if let value = plist[key] as? String {
                entries.append((key: key, value: value))
            }
        }

        return entries
    }

    private static func formatPlistValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            return str
        case let bool as Bool:
            return bool ? "true" : "false"
        case let num as NSNumber:
            return num.stringValue
        case let arr as [Any]:
            return "[\(arr.count) items]"
        case let dict as [String: Any]:
            return "{\(dict.count) keys}"
        default:
            return "\(value)"
        }
    }
}
