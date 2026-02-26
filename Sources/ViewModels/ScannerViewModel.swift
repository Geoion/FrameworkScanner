import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class ScannerViewModel: ObservableObject {

    // MARK: - Published State

    @Published var allApps: [AppInfo] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var scanCurrent: Int = 0
    @Published var scanTotal: Int = 0
    @Published var scanCurrentIcon: NSImage?

    @Published var searchText = ""
    @Published var selectedFrameworks: Set<FrameworkType> = []
    @Published var selectedSources: Set<AppSource> = []
    @Published var sortOption: SortOption = .name
    @Published var sortDirection: SortDirection = .ascending

    @Published var needsPermission = false
    @Published var permissionError = false

    @Published private(set) var filteredApps: [AppInfo] = []

    // MARK: - Computed

    var stats: ScanStats {
        ScanStats(apps: allApps)
    }

    // MARK: - Private

    private let scanner = AppScanner()
    private let bookmarkManager = BookmarkManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest4(
            $allApps,
            $searchText.debounce(for: .milliseconds(150), scheduler: RunLoop.main),
            Publishers.CombineLatest($selectedFrameworks, $selectedSources),
            Publishers.CombineLatest($sortOption, $sortDirection)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] apps, search, filterPair, sortPair in
            self?.recomputeFiltered(
                apps: apps, search: search,
                frameworks: filterPair.0, sources: filterPair.1,
                sortOption: sortPair.0, sortDirection: sortPair.1
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Actions

    func checkPermissionAndScan() {
        guard allApps.isEmpty && !isScanning else { return }

        if let url = bookmarkManager.resolveBookmark() {
            if bookmarkManager.startAccessing(url) {
                let plan = buildScanPlan(userGranted: url)
                Task { await performScan(plan: plan) }
            } else {
                needsPermission = true
            }
        } else {
            needsPermission = true
        }
    }

    func requestPermission() {
        Task {
            guard let url = await bookmarkManager.requestAccess() else {
                permissionError = true
                return
            }
            if bookmarkManager.startAccessing(url) {
                needsPermission = false
                let plan = buildScanPlan(userGranted: url)
                await performScan(plan: plan)
            }
        }
    }

    func rescan() {
        if let url = bookmarkManager.resolveBookmark(), bookmarkManager.startAccessing(url) {
            let plan = buildScanPlan(userGranted: url)
            Task { await performScan(plan: plan) }
        } else {
            needsPermission = true
        }
    }

    func exportAsCSV() {
        let panel = NSSavePanel()
        panel.title = L("Export as CSV")
        panel.nameFieldStringValue = "FrameworkScanner.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let csv = ExportService.generateCSV(from: filteredApps)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportAsJSON() {
        let panel = NSSavePanel()
        panel.title = L("Export as JSON")
        panel.nameFieldStringValue = "FrameworkScanner.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let json = ExportService.generateJSON(from: filteredApps)
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Methods

    private func recomputeFiltered(
        apps: [AppInfo], search: String,
        frameworks: Set<FrameworkType>, sources: Set<AppSource>,
        sortOption: SortOption, sortDirection: SortDirection
    ) {
        var result = apps

        if !search.isEmpty {
            let query = search.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query)
            }
        }

        if !frameworks.isEmpty {
            result = result.filter { frameworks.contains($0.frameworkType) }
        }

        if !sources.isEmpty {
            result = result.filter { app in sources.contains { $0.matches(app) } }
        }

        let ascending = sortDirection == .ascending
        result.sort { a, b in
            let cmp: Bool
            switch sortOption {
            case .name:
                cmp = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size:
                cmp = a.appSize < b.appSize
            case .date:
                cmp = a.installDate < b.installDate
            case .framework:
                cmp = a.frameworkType.displayName < b.frameworkType.displayName
            }
            return ascending ? cmp : !cmp
        }

        filteredApps = result
    }

    private func performScan(plan: ScanPlan) async {
        isScanning = true
        scanCurrent = 0
        scanTotal = 0
        scanCurrentIcon = nil
        scanProgress = L("Scanning applications...")

        let results = await scanner.scan(
            directories: plan.dirs,
            homebrewDirs: plan.homebrewDirs,
            systemAppDirs: plan.systemAppDirs
        ) { [weak self] progress in
            Task { @MainActor in
                guard let self else { return }
                if progress.current > self.scanCurrent {
                    self.scanCurrent = progress.current
                }
                self.scanTotal = progress.total
                self.scanProgress = progress.currentAppName
                self.scanCurrentIcon = progress.currentAppIcon
            }
        }

        allApps = results
        isScanning = false
        scanProgress = ""
        scanCurrentIcon = nil

        bookmarkManager.stopAccessing()
    }

    private func buildScanPlan(userGranted: URL) -> ScanPlan {
        var dirs: [URL] = [userGranted, userApplicationsURL]
        var homebrewDirs: Set<URL> = []
        var systemAppDirs: Set<URL> = []

        let systemApps = URL(fileURLWithPath: "/System/Applications")
        if FileManager.default.fileExists(atPath: systemApps.path) {
            dirs.append(systemApps)
            systemAppDirs.insert(systemApps.standardizedFileURL)
        }

        for caskRoot in homebrewCaskRoots {
            if FileManager.default.fileExists(atPath: caskRoot.path) {
                let versionDirs = homebrewAppURLs(in: caskRoot)
                dirs.append(contentsOf: versionDirs)
                versionDirs.forEach { homebrewDirs.insert($0.standardizedFileURL) }
            }
        }

        return ScanPlan(dirs: dirs, homebrewDirs: homebrewDirs, systemAppDirs: systemAppDirs)
    }

    private var userApplicationsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    }

    private var homebrewCaskRoots: [URL] {
        [
            URL(fileURLWithPath: "/opt/homebrew/Caskroom"),
            URL(fileURLWithPath: "/usr/local/Caskroom")
        ]
    }

    /// 从 Homebrew Caskroom 目录中找出所有 .app 所在的父目录
    /// 结构：Caskroom/<cask-name>/<version>/<App.app>
    /// 返回各版本目录，让 AppScanner 去枚举其中的 .app
    private func homebrewAppURLs(in caskRoot: URL) -> [URL] {
        let fm = FileManager.default
        guard let casks = try? fm.contentsOfDirectory(
            at: caskRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var versionDirs: [URL] = []
        for cask in casks {
            guard let versions = try? fm.contentsOfDirectory(
                at: cask,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            versionDirs.append(contentsOf: versions)
        }
        return versionDirs
    }
}

// MARK: - Scan Plan

private struct ScanPlan {
    let dirs: [URL]
    let homebrewDirs: Set<URL>
    let systemAppDirs: Set<URL>
}

// MARK: - Stats

struct ScanStats {
    let total: Int
    let frameworkCounts: [(type: FrameworkType, count: Int)]
    let electronCount: Int
    let electronTotalSize: Int64

    init(apps: [AppInfo]) {
        total = apps.count

        var counts: [FrameworkType: Int] = [:]
        var electronSize: Int64 = 0

        for app in apps {
            counts[app.frameworkType, default: 0] += 1
            if app.frameworkType == .electron {
                electronSize += app.appSize
            }
        }

        frameworkCounts = counts
            .sorted { $0.value > $1.value }
            .map { (type: $0.key, count: $0.value) }

        electronCount = counts[.electron] ?? 0
        electronTotalSize = electronSize
    }

    func percentage(for type: FrameworkType) -> String {
        guard total > 0 else { return "0%" }
        let count = frameworkCounts.first(where: { $0.type == type })?.count ?? 0
        let pct = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", pct)
    }
}
