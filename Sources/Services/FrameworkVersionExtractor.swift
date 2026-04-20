import Foundation

/// 从非 Electron 框架的 bundle 中提取版本信息
struct FrameworkVersionExtractor {

    /// 返回 framework name → version string 的字典
    static func extract(at appURL: URL, for frameworkTypes: [FrameworkType]) -> [String: String] {
        var versions: [String: String] = [:]
        if frameworkTypes.contains(.qt) {
            if let v = qtVersion(at: appURL) { versions["qt"] = v }
        }
        if frameworkTypes.contains(.python) {
            if let v = pythonVersion(at: appURL) { versions["python"] = v }
        }
        if frameworkTypes.contains(.cef) {
            if let v = cefVersion(at: appURL) { versions["cef"] = v }
        }
        return versions
    }

    // MARK: - Qt

    private static func qtVersion(at appURL: URL) -> String? {
        let fwDir = appURL.appendingPathComponent("Contents/Frameworks/QtCore.framework")
        // 标准 macOS framework 布局：Versions/A/Resources/Info.plist
        // 也可能通过 symlink 直接在 Resources/ 下
        let candidates = [
            fwDir.appendingPathComponent("Versions/A/Resources/Info.plist"),
            fwDir.appendingPathComponent("Resources/Info.plist"),
        ]
        for url in candidates {
            if let v = readPlistVersion(at: url) { return v }
        }
        return nil
    }

    // MARK: - Python

    private static func pythonVersion(at appURL: URL) -> String? {
        let versionsDir = appURL.appendingPathComponent("Contents/Frameworks/Python.framework/Versions")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: versionsDir.path) else { return nil }

        // 排除 "Current" 符号链接，取版本号最高的目录
        let versionDirs = entries
            .filter { $0 != "Current" }
            .sorted { versionGreater($0, $1) }

        for dir in versionDirs {
            let base = versionsDir.appendingPathComponent(dir)
            // Python 3.x 的两个常见 Info.plist 位置
            let candidates = [
                base.appendingPathComponent("Resources/Info.plist"),
                base.appendingPathComponent("lib/python\(dir)/site-packages/Info.plist"),
            ]
            for url in candidates {
                if let v = readPlistVersion(at: url) { return v }
            }
            // 没找到 plist 时用目录名作为粗粒度版本（如 "3.11"）
            if fm.fileExists(atPath: base.appendingPathComponent("Python").path) {
                return dir
            }
        }
        return nil
    }

    // MARK: - CEF

    private static func cefVersion(at appURL: URL) -> String? {
        let fwDir = appURL.appendingPathComponent("Contents/Frameworks/Chromium Embedded Framework.framework")
        let candidates = [
            fwDir.appendingPathComponent("Versions/A/Resources/Info.plist"),
            fwDir.appendingPathComponent("Resources/Info.plist"),
        ]
        for url in candidates {
            if let v = readPlistVersion(at: url) { return v }
        }
        return nil
    }

    // MARK: - Helpers

    private static func readPlistVersion(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String)
    }

    /// 比较两个版本字符串（"3.12" > "3.11"，"3.9" > "2.7"）
    private static func versionGreater(_ a: String, _ b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va != vb { return va > vb }
        }
        return false
    }
}
