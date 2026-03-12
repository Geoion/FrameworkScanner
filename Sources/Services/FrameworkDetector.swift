import Foundation

struct FrameworkDetector {

    static func detect(at appURL: URL) -> FrameworkType {
        detectAll(at: appURL).first ?? .appKit
    }

    static func detectAll(at appURL: URL) -> [FrameworkType] {
        let frameworksDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")
        let resourcesDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
        let contentsDir = appURL.appendingPathComponent("Contents")

        let fm = FileManager.default

        let frameworkNames = (try? fm.contentsOfDirectory(atPath: frameworksDir.path)) ?? []
        let resourceNames = (try? fm.contentsOfDirectory(atPath: resourcesDir.path)) ?? []
        var detected: [FrameworkType] = []

        func append(_ framework: FrameworkType) {
            if !detected.contains(framework) {
                detected.append(framework)
            }
        }

        // Electron: Electron Framework.framework
        if frameworkNames.contains(where: { $0.hasPrefix("Electron") && $0.hasSuffix(".framework") }) {
            append(.electron)
        }

        // CEF: Chromium Embedded Framework
        if frameworkNames.contains("Chromium Embedded Framework.framework") {
            append(.cef)
        }

        // Flutter: FlutterMacOS.framework
        if frameworkNames.contains("FlutterMacOS.framework") ||
           frameworkNames.contains("App.framework") && frameworkNames.contains("FlutterMacOS.framework") {
            append(.flutter)
        }

        // Qt: QtCore, QtWidgets, etc.
        if frameworkNames.contains(where: { $0.hasPrefix("Qt") && $0.hasSuffix(".framework") }) {
            append(.qt)
        }

        // Unity: UnityPlayer or Data/Managed
        let dataDir = contentsDir.appendingPathComponent("Data")
        let managedDir = dataDir.appendingPathComponent("Managed")
        if frameworkNames.contains(where: { $0.contains("UnityPlayer") }) ||
           fm.fileExists(atPath: managedDir.path) {
            append(.unity)
        }

        // Unreal Engine
        if frameworkNames.contains(where: { $0.contains("UE4") || $0.contains("UnrealEngine") }) {
            append(.unreal)
        }

        // .NET / MAUI / Mono
        if frameworkNames.contains(where: { $0.contains("Mono") || $0.contains("dotnet") }) ||
           resourceNames.contains(where: { $0.hasSuffix(".dll") }) {
            append(.dotNet)
        }

        // Java/JVM: .jar files or libjvm
        if resourceNames.contains(where: { $0.hasSuffix(".jar") }) ||
           frameworkNames.contains(where: { $0.contains("libjvm") }) ||
           hasJavaIndicators(contentsDir: contentsDir) {
            append(.javaJVM)
        }

        // React Native macOS: RCTBridge or ReactCommon framework
        if frameworkNames.contains(where: { $0.contains("React") || $0.contains("RCT") }) ||
           resourceNames.contains(where: { $0 == "main.jsbundle" || $0.hasSuffix(".jsbundle") }) {
            append(.reactNative)
        }

        // Capacitor: capacitor.config.json or @capacitor in resources
        if resourceNames.contains("capacitor.config.json") ||
           resourceNames.contains(where: { $0.contains("capacitor") }) {
            append(.capacitor)
        }

        // Python (PyInstaller): _MEIPASS marker or pyinstaller bootloader
        if isPythonApp(contentsDir: contentsDir, resourceNames: resourceNames) {
            append(.python)
        }

        // Go / Wails: wails.json or specific Go runtime indicators
        if isGoWailsApp(contentsDir: contentsDir, resourceNames: resourceNames, frameworkNames: frameworkNames) {
            append(.go)
        }

        // Tauri: small app with WebKit usage but no Electron
        if isTauri(frameworkNames: frameworkNames, appURL: appURL) {
            append(.tauri)
        }

        // Catalyst / UIKit
        if let plist = readInfoPlist(at: appURL) {
            if plist["LSRequiresIPhoneOS"] as? Bool == true ||
               plist["UIRequiredDeviceCapabilities"] != nil {
                append(.catalyst)
            }
        }

        // SwiftUI detection via linked frameworks in binary
        if hasSwiftUIReference(at: appURL) {
            append(.swiftUI)
        }

        if detected.isEmpty {
            detected.append(.appKit)
        }

        return detected
    }

    // MARK: - Helpers

    private static func readInfoPlist(at appURL: URL) -> [String: Any]? {
        let plistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    private static func hasJavaIndicators(contentsDir: URL) -> Bool {
        let javaDir = contentsDir.appendingPathComponent("Java")
        return FileManager.default.fileExists(atPath: javaDir.path)
    }

    private static func isPythonApp(contentsDir: URL, resourceNames: [String]) -> Bool {
        let fm = FileManager.default
        // PyInstaller 打包特征：_MEIPASS 目录或 base_library.zip
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let macOSFiles = (try? fm.contentsOfDirectory(atPath: macOSDir.path)) ?? []
        if macOSFiles.contains("base_library.zip") ||
           macOSFiles.contains(where: { $0.hasSuffix(".pkg") && $0.contains("python") }) {
            return true
        }
        // Python.framework 内嵌
        let frameworksDir = contentsDir.appendingPathComponent("Frameworks")
        let frameworkNames = (try? fm.contentsOfDirectory(atPath: frameworksDir.path)) ?? []
        if frameworkNames.contains(where: { $0.hasPrefix("Python") && $0.hasSuffix(".framework") }) {
            return true
        }
        return resourceNames.contains(where: { $0.hasSuffix(".pyc") || $0 == "python3" })
    }

    private static func isGoWailsApp(contentsDir: URL, resourceNames: [String], frameworkNames: [String]) -> Bool {
        let fm = FileManager.default
        // Wails 特征：wails.json 或 frontend 目录下的 index.html
        if resourceNames.contains("wails.json") { return true }
        let macOSDir = contentsDir.appendingPathComponent("MacOS")
        let macOSFiles = (try? fm.contentsOfDirectory(atPath: macOSDir.path)) ?? []
        // Go 二进制通常无外部依赖，但 Wails 会有 WebKit 且含 wails 相关文件
        if frameworkNames.contains(where: { $0.contains("WebKit") }) &&
           (resourceNames.contains(where: { $0.contains("wails") }) ||
            macOSFiles.contains(where: { $0.contains("wails") })) {
            return true
        }
        return false
    }

    private static func isTauri(frameworkNames: [String], appURL: URL) -> Bool {
        let hasWebKit = frameworkNames.contains(where: { $0.contains("WebKit") })
        if !hasWebKit { return false }

        let tauriIndicators = ["_lib_tauri", "tauri"]
        let resourcesDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
        let resourceNames = (try? FileManager.default.contentsOfDirectory(atPath: resourcesDir.path)) ?? []

        return resourceNames.contains(where: { name in
            tauriIndicators.contains(where: { name.lowercased().contains($0) })
        })
    }

    private static func hasSwiftUIReference(at appURL: URL) -> Bool {
        let frameworksDir = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Frameworks")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: frameworksDir.path)) ?? []

        if names.contains(where: { $0.contains("SwiftUI") }) {
            return true
        }

        // Check the binary for SwiftUI linkage using otool
        guard let executableURL = Bundle(url: appURL)?.executableURL else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = ["-L", executableURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("SwiftUI")
        } catch {
            return false
        }
    }
}
