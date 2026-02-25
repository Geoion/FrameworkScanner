import Foundation
import AppKit

final class BookmarkManager {
    static let shared = BookmarkManager()

    private let bookmarkKey = "applicationsFolderBookmark"

    private var accessingURL: URL?

    func hasBookmark() -> Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    /// 尝试从已保存的 bookmark 恢复目录访问权限
    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                if saveBookmark(for: url) {
                    return url
                }
                return nil
            }
            return url
        } catch {
            return nil
        }
    }

    func startAccessing(_ url: URL) -> Bool {
        stopAccessing()
        let success = url.startAccessingSecurityScopedResource()
        if success {
            accessingURL = url
        }
        return success
    }

    func stopAccessing() {
        accessingURL?.stopAccessingSecurityScopedResource()
        accessingURL = nil
    }

    @discardableResult
    func saveBookmark(for url: URL) -> Bool {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            return true
        } catch {
            return false
        }
    }

    /// 弹出 NSOpenPanel 让用户选择 Applications 目录
    func requestAccess() async -> URL? {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.title = L("Select Applications Folder")
            panel.message = L("FrameworkScanner needs access to the Applications folder to scan installed apps.")
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")

            let response = panel.runModal()
            guard response == .OK, let url = panel.url else {
                return nil
            }

            saveBookmark(for: url)
            return url
        }
    }
}
