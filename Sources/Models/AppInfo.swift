import Foundation
import AppKit

struct ElectronDetail {
    var electronVersion: String?
    var chromiumVersion: String?
    var nodeVersion: String?
}

struct AppInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let version: String
    let icon: NSImage
    let frameworkType: FrameworkType
    let appSize: Int64
    let installDate: Date
    let architecture: Architecture
    let path: URL
    var electronDetail: ElectronDetail?
    let isFromHomebrew: Bool
    let isSystemApp: Bool

    let formattedSize: String
    let formattedDate: String

    init(
        id: String, name: String, bundleIdentifier: String, version: String,
        icon: NSImage, frameworkType: FrameworkType, appSize: Int64,
        installDate: Date, architecture: Architecture, path: URL,
        electronDetail: ElectronDetail? = nil,
        isFromHomebrew: Bool = false,
        isSystemApp: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.frameworkType = frameworkType
        self.appSize = appSize
        self.installDate = installDate
        self.architecture = architecture
        self.path = path
        self.electronDetail = electronDetail
        self.isFromHomebrew = isFromHomebrew
        self.isSystemApp = isSystemApp

        // 预缩放图标到 40pt (80px @2x) 避免列表滚动时重复缩放
        let targetSize = NSSize(width: 40, height: 40)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        icon.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        resized.isTemplate = icon.isTemplate
        self.icon = resized

        self.formattedSize = ByteCountFormatter.string(fromByteCount: appSize, countStyle: .file)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        self.formattedDate = formatter.string(from: installDate)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.version == rhs.version
    }
}

enum Architecture: String {
    case arm64 = "Apple Silicon"
    case x86_64 = "Intel"
    case universal = "Universal"
    case unknown = "Unknown"
}

struct EmbeddedFramework: Identifiable {
    let id: String
    let name: String
    let path: String
    let version: String
    let size: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
