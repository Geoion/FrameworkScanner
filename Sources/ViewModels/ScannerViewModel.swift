import Foundation
import SwiftUI
import Combine

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
            $selectedFrameworks,
            Publishers.CombineLatest($sortOption, $sortDirection)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] apps, search, frameworks, sortPair in
            self?.recomputeFiltered(
                apps: apps, search: search, frameworks: frameworks,
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
                Task { await performScan(directories: [url, userApplicationsURL]) }
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
                await performScan(directories: [url, userApplicationsURL])
            }
        }
    }

    func rescan() {
        if let url = bookmarkManager.resolveBookmark(), bookmarkManager.startAccessing(url) {
            Task { await performScan(directories: [url, userApplicationsURL]) }
        } else {
            needsPermission = true
        }
    }

    // MARK: - Private Methods

    private func recomputeFiltered(
        apps: [AppInfo], search: String, frameworks: Set<FrameworkType>,
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

    private func performScan(directories: [URL]) async {
        isScanning = true
        scanCurrent = 0
        scanTotal = 0
        scanCurrentIcon = nil
        scanProgress = L("Scanning applications...")

        let results = await scanner.scan(directories: directories) { [weak self] progress in
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

    private var userApplicationsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    }
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
