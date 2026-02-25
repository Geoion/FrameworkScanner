import Foundation

struct ElectronAnalyzer {

    /// 从 Electron 应用中提取版本详情
    static func analyze(at appURL: URL) -> ElectronDetail {
        var detail = ElectronDetail()

        let frameworksDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")

        // 查找 Electron Framework.framework 目录
        let electronFrameworkDir = frameworksDir.appendingPathComponent("Electron Framework.framework")

        // 方式 1: 从 Electron Framework 的 Info.plist 读取版本
        let fwPlistURL = electronFrameworkDir
            .appendingPathComponent("Resources")
            .appendingPathComponent("Info.plist")
        if let data = try? Data(contentsOf: fwPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            detail.electronVersion = plist["CFBundleShortVersionString"] as? String
                ?? plist["CFBundleVersion"] as? String
        }

        // 方式 2: 从 LICENSES.chromium.html 或 version 文件获取 Chromium 版本
        let versionFileLocations = [
            appURL.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/LICENSES.chromium.html"),
            appURL.appendingPathComponent("Contents/Resources/LICENSES.chromium.html"),
        ]

        for location in versionFileLocations {
            if let content = try? String(contentsOf: location, encoding: .utf8) {
                detail.chromiumVersion = extractChromiumVersion(from: content)
                if detail.chromiumVersion != nil { break }
            }
        }

        // 方式 3: 从 package.json 或 electron.asar 获取 Node 版本
        let resourcesDir = appURL.appendingPathComponent("Contents/Resources")
        let packageJSON = resourcesDir.appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: packageJSON),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let engines = json["engines"] as? [String: Any] {
                detail.nodeVersion = engines["node"] as? String
            }
        }

        // 通过 Electron 版本推断 Chromium/Node 版本
        if detail.electronVersion != nil && (detail.chromiumVersion == nil || detail.nodeVersion == nil) {
            let inferred = inferVersions(electronVersion: detail.electronVersion!)
            if detail.chromiumVersion == nil { detail.chromiumVersion = inferred.chromium }
            if detail.nodeVersion == nil { detail.nodeVersion = inferred.node }
        }

        return detail
    }

    private static func extractChromiumVersion(from html: String) -> String? {
        // Chromium 版本通常在 LICENSES 文件标题中
        if let range = html.range(of: #"Chromium (\d+\.\d+\.\d+\.\d+)"#, options: .regularExpression) {
            let match = html[range]
            return match.replacingOccurrences(of: "Chromium ", with: "")
        }
        return nil
    }

    /// 已知 Electron 主版本与 Chromium / Node 大版本的对应关系
    private static func inferVersions(electronVersion: String) -> (chromium: String?, node: String?) {
        guard let major = Int(electronVersion.split(separator: ".").first ?? "") else {
            return (nil, nil)
        }

        let mapping: [Int: (chromium: String, node: String)] = [
            33: ("132.x", "22.x"),
            32: ("132.x", "22.x"),
            31: ("130.x", "20.x"),
            30: ("128.x", "20.x"),
            29: ("122.x", "20.x"),
            28: ("120.x", "18.x"),
            27: ("118.x", "18.x"),
            26: ("116.x", "18.x"),
            25: ("114.x", "18.x"),
            24: ("112.x", "18.x"),
            23: ("110.x", "18.x"),
            22: ("108.x", "16.x"),
        ]

        if let versions = mapping[major] {
            return (versions.chromium, versions.node)
        }
        return (nil, nil)
    }
}
