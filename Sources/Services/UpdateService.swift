import Foundation

struct AppRelease: Sendable {
    let tagName: String
    let name: String
    let body: String
    let htmlURL: URL

    var version: String {
        let raw = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

actor UpdateService {
    static let shared = UpdateService()

    private let apiURL = URL(string: "https://api.github.com/repos/Geoion/FrameworkScanner/releases/latest")!

    func checkForUpdates(currentVersion: String) async throws -> AppRelease? {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        let payload = try JSONDecoder().decode(GitHubReleasePayload.self, from: data)
        let release = AppRelease(
            tagName: payload.tagName,
            name: payload.name,
            body: payload.body ?? "",
            htmlURL: payload.htmlURL
        )

        guard isNewer(version: release.version, than: currentVersion) else {
            return nil
        }

        return release
    }

    private func isNewer(version: String, than currentVersion: String) -> Bool {
        let lhs = parseVersion(version)
        let rhs = parseVersion(currentVersion)
        let count = max(lhs.count, rhs.count)

        for idx in 0..<count {
            let left = idx < lhs.count ? lhs[idx] : 0
            let right = idx < rhs.count ? rhs[idx] : 0
            if left != right { return left > right }
        }

        return false
    }

    private func parseVersion(_ rawVersion: String) -> [Int] {
        let cleaned = rawVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""

        return cleaned.split(separator: ".").map { component in
            Int(component.prefix { $0.isNumber }) ?? 0
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let name: String
    let body: String?
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
    }
}
