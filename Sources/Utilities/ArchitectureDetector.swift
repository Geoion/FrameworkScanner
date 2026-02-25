import Foundation

struct ArchitectureDetector {
    static func detect(at appURL: URL) -> Architecture {
        let executableName = Bundle(url: appURL)?.executableURL?.lastPathComponent
            ?? appURL.deletingPathExtension().lastPathComponent
        let executableURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(executableName)

        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            return .unknown
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [executableURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let hasArm = output.contains("arm64")
            let hasX86 = output.contains("x86_64")

            if hasArm && hasX86 {
                return .universal
            } else if hasArm {
                return .arm64
            } else if hasX86 {
                return .x86_64
            }
            return .unknown
        } catch {
            return .unknown
        }
    }
}
