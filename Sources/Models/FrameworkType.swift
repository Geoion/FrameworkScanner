import Foundation

enum FrameworkType: String, CaseIterable, Identifiable, Codable {
    case electron = "Electron"
    case swiftUI = "SwiftUI"
    case appKit = "AppKit"
    case catalyst = "Catalyst"
    case qt = "Qt"
    case flutter = "Flutter"
    case tauri = "Tauri"
    case javaJVM = "Java/JVM"
    case cef = "CEF"
    case dotNet = ".NET/MAUI"
    case unity = "Unity"
    case unreal = "Unreal Engine"
    case python = "Python"
    case go = "Go/Wails"
    case reactNative = "React Native"
    case capacitor = "Capacitor"
    case unknown = "Unknown"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var symbolName: String {
        switch self {
        case .electron: return "bolt.fill"
        case .swiftUI: return "swift"
        case .appKit: return "macwindow"
        case .catalyst: return "iphone.and.arrow.forward"
        case .qt: return "cube.fill"
        case .flutter: return "bird.fill"
        case .tauri: return "globe"
        case .javaJVM: return "cup.and.saucer.fill"
        case .cef: return "network"
        case .dotNet: return "square.stack.3d.up.fill"
        case .unity: return "gamecontroller.fill"
        case .unreal: return "film.fill"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .go: return "arrow.triangle.2.circlepath"
        case .reactNative: return "iphone"
        case .capacitor: return "bolt.circle.fill"
        case .unknown: return "questionmark.app"
        }
    }

    var isElectron: Bool { self == .electron }
}
