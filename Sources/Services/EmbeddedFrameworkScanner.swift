import Foundation

struct EmbeddedFrameworkScanner {

    static func scan(appURL: URL) -> [EmbeddedFramework] {
        let frameworksDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")

        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: frameworksDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [EmbeddedFramework] = []

        for item in items {
            let ext = item.pathExtension.lowercased()
            guard ext == "framework" || ext == "dylib" else { continue }

            let name = item.deletingPathExtension().lastPathComponent
            let relativePath = "Contents/Frameworks/\(item.lastPathComponent)"

            var version = "–"
            if ext == "framework" {
                let plistURL = item
                    .appendingPathComponent("Resources")
                    .appendingPathComponent("Info.plist")
                let altPlistURL = item.appendingPathComponent("Info.plist")

                let plistData = (try? Data(contentsOf: plistURL))
                    ?? (try? Data(contentsOf: altPlistURL))

                if let data = plistData,
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                    version = (plist["CFBundleShortVersionString"] as? String)
                        ?? (plist["CFBundleVersion"] as? String)
                        ?? "–"
                }
            }

            let size = FileSizeCalculator.directorySize(at: item)

            results.append(EmbeddedFramework(
                id: relativePath,
                name: name,
                path: relativePath,
                version: version,
                size: size
            ))
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
