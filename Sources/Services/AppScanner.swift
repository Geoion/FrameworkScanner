import Foundation
import AppKit

struct ScanProgress: @unchecked Sendable {
    let current: Int
    let total: Int
    let currentAppName: String
    let currentAppIcon: NSImage?
}

actor AppScanner {

    func scan(
        directories: [URL],
        homebrewAppPaths: Set<String> = [],
        systemAppDirs: Set<URL> = [],
        recursiveScan: Bool = false,
        maxDepth: Int = 2,
        excludedPaths: Set<String> = [],
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> [AppInfo] {
        var allAppURLs: [URL] = []

        for directory in directories {
            if isExcluded(directory, excludedPaths: excludedPaths) {
                continue
            }
            allAppURLs.append(contentsOf: appBundles(
                in: directory,
                recursiveScan: recursiveScan,
                maxDepth: maxDepth,
                excludedPaths: excludedPaths
            ))
        }

        // 去重（同一个 .app 可能通过多个目录被枚举到）
        var seen = Set<String>()
        allAppURLs = allAppURLs.filter { seen.insert($0.resolvingSymlinksInPath().standardizedFileURL.path).inserted }

        let total = allAppURLs.count
        if total == 0 { return [] }

        let counter = Counter()

        return await withTaskGroup(of: AppInfo?.self, returning: [AppInfo].self) { group in
            let maxConcurrency = 8
            var index = 0
            var results: [AppInfo] = []

            for _ in 0..<min(maxConcurrency, total) {
                let url = allAppURLs[index]
                let realPath = url.resolvingSymlinksInPath().standardizedFileURL.path
                let isHomebrew = homebrewAppPaths.contains(realPath)
                let isSystem = isSystemApp(url, systemAppDirs: systemAppDirs)
                index += 1
                group.addTask {
                    await self.processApp(url: url, isFromHomebrew: isHomebrew, isSystemApp: isSystem, total: total, counter: counter, onProgress: onProgress)
                }
            }

            for await result in group {
                if let info = result {
                    results.append(info)
                }
                if index < total {
                    let url = allAppURLs[index]
                    let realPath = url.resolvingSymlinksInPath().standardizedFileURL.path
                    let isHomebrew = homebrewAppPaths.contains(realPath)
                    let isSystem = isSystemApp(url, systemAppDirs: systemAppDirs)
                    index += 1
                    group.addTask {
                        await self.processApp(url: url, isFromHomebrew: isHomebrew, isSystemApp: isSystem, total: total, counter: counter, onProgress: onProgress)
                    }
                }
            }

            return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func processApp(
        url: URL, isFromHomebrew: Bool, isSystemApp: Bool, total: Int, counter: Counter,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> AppInfo? {
        let icon = await MainActor.run { NSWorkspace.shared.icon(forFile: url.path) }
        let name = url.deletingPathExtension().lastPathComponent
        let currentBefore = await counter.value

        // 只更新图标和名称，current 保持上一次已完成的值
        onProgress(ScanProgress(current: currentBefore, total: total, currentAppName: name, currentAppIcon: icon))

        let info = await self.extractAppInfo(from: url, isFromHomebrew: isFromHomebrew, isSystemApp: isSystemApp)
        let currentAfter = await counter.increment()

        onProgress(ScanProgress(current: currentAfter, total: total, currentAppName: name, currentAppIcon: icon))

        return info
    }

    private func extractAppInfo(from appURL: URL, isFromHomebrew: Bool = false, isSystemApp: Bool = false) async -> AppInfo? {
        let fm = FileManager.default
        let plistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard fm.fileExists(atPath: plistURL.path),
              let plistData = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        let bundleID = (plist["CFBundleIdentifier"] as? String) ?? "unknown"
        let version = (plist["CFBundleShortVersionString"] as? String) ?? "–"

        let icon = await MainActor.run {
            NSWorkspace.shared.icon(forFile: appURL.path)
        }

        let frameworkTypes = FrameworkDetector.detectAll(at: appURL)
        let frameworkType = frameworkTypes.first ?? .appKit

        let appSize = FileSizeCalculator.directorySize(at: appURL)

        let installDate = (try? fm.attributesOfItem(atPath: appURL.path)[.creationDate] as? Date)
            ?? Date.distantPast

        let architecture = ArchitectureDetector.detect(at: appURL)

        var electronDetail: ElectronDetail?
        if frameworkTypes.contains(.electron) {
            electronDetail = ElectronAnalyzer.analyze(at: appURL)
        }

        let frameworkVersions = FrameworkVersionExtractor.extract(at: appURL, for: frameworkTypes)

        let appInfo = AppInfo(
            id: bundleID,
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            icon: icon,
            frameworkType: frameworkType,
            appSize: appSize,
            installDate: installDate,
            architecture: architecture,
            path: appURL,
            detectedFrameworks: frameworkTypes,
            electronDetail: electronDetail,
            frameworkVersions: frameworkVersions,
            isFromHomebrew: isFromHomebrew,
            isSystemApp: isSystemApp,
            securityIssues: SecurityAnalyzer.analyze(app: AppInfo(
                id: bundleID, name: name, bundleIdentifier: bundleID, version: version,
                icon: icon, frameworkType: frameworkType, appSize: appSize,
                installDate: installDate, architecture: architecture, path: appURL,
                detectedFrameworks: frameworkTypes,
                electronDetail: electronDetail, frameworkVersions: frameworkVersions,
                isFromHomebrew: isFromHomebrew, isSystemApp: isSystemApp
            ))
        )
        return appInfo
    }

    private func appBundles(
        in directory: URL,
        recursiveScan: Bool,
        maxDepth: Int,
        excludedPaths: Set<String>
    ) -> [URL] {
        let fm = FileManager.default

        if !recursiveScan {
            guard let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return contents.filter { $0.pathExtension == "app" && !isExcluded($0, excludedPaths: excludedPaths) }
        }

        var apps: [URL] = []
        let root = directory.standardizedFileURL
        let rootDepth = root.pathComponents.count
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else { return [] }

        for case let item as URL in enumerator {
            let current = item.standardizedFileURL
            if isExcluded(current, excludedPaths: excludedPaths) {
                enumerator.skipDescendants()
                continue
            }

            let depth = current.pathComponents.count - rootDepth
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            if current.pathExtension == "app" {
                apps.append(current)
                enumerator.skipDescendants()
            }
        }

        return apps
    }

    private func isSystemApp(_ appURL: URL, systemAppDirs: Set<URL>) -> Bool {
        let appPath = appURL.standardizedFileURL.path
        return systemAppDirs.contains { dir in
            let root = dir.standardizedFileURL.path
            return appPath.hasPrefix(root + "/")
        }
    }

    private func isExcluded(_ url: URL, excludedPaths: Set<String>) -> Bool {
        let path = url.standardizedFileURL.path
        return excludedPaths.contains { excluded in
            path == excluded || path.hasPrefix(excluded + "/")
        }
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() -> Int {
        value += 1
        return value
    }
}
