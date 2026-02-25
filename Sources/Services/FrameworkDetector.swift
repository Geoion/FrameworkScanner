import Foundation

struct FrameworkDetector {

    static func detect(at appURL: URL) -> FrameworkType {
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

        // Electron: Electron Framework.framework
        if frameworkNames.contains(where: { $0.hasPrefix("Electron") && $0.hasSuffix(".framework") }) {
            return .electron
        }

        // CEF: Chromium Embedded Framework
        if frameworkNames.contains("Chromium Embedded Framework.framework") {
            return .cef
        }

        // Flutter: FlutterMacOS.framework
        if frameworkNames.contains("FlutterMacOS.framework") ||
           frameworkNames.contains("App.framework") && frameworkNames.contains("FlutterMacOS.framework") {
            return .flutter
        }

        // Qt: QtCore, QtWidgets, etc.
        if frameworkNames.contains(where: { $0.hasPrefix("Qt") && $0.hasSuffix(".framework") }) {
            return .qt
        }

        // Unity: UnityPlayer or Data/Managed
        let dataDir = contentsDir.appendingPathComponent("Data")
        let managedDir = dataDir.appendingPathComponent("Managed")
        if frameworkNames.contains(where: { $0.contains("UnityPlayer") }) ||
           fm.fileExists(atPath: managedDir.path) {
            return .unity
        }

        // Unreal Engine
        if frameworkNames.contains(where: { $0.contains("UE4") || $0.contains("UnrealEngine") }) {
            return .unreal
        }

        // .NET / MAUI / Mono
        if frameworkNames.contains(where: { $0.contains("Mono") || $0.contains("dotnet") }) ||
           resourceNames.contains(where: { $0.hasSuffix(".dll") }) {
            return .dotNet
        }

        // Java/JVM: .jar files or libjvm
        if resourceNames.contains(where: { $0.hasSuffix(".jar") }) ||
           frameworkNames.contains(where: { $0.contains("libjvm") }) ||
           hasJavaIndicators(contentsDir: contentsDir) {
            return .javaJVM
        }

        // Tauri: small app with WebKit usage but no Electron
        if isTauri(frameworkNames: frameworkNames, appURL: appURL) {
            return .tauri
        }

        // Catalyst / UIKit
        if let plist = readInfoPlist(at: appURL) {
            if plist["LSRequiresIPhoneOS"] as? Bool == true ||
               plist["UIRequiredDeviceCapabilities"] != nil {
                return .catalyst
            }
        }

        // SwiftUI detection via linked frameworks in binary
        if hasSwiftUIReference(at: appURL) {
            return .swiftUI
        }

        return .appKit
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
