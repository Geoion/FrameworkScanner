import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case german = "de"
    case spanish = "es"
    case italian = "it"
    case russian = "ru"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        case .russian: return "Русский"
        }
    }

    var effectiveCode: String {
        if self != .system { return rawValue }
        let preferred = Locale.preferredLanguages.first ?? "en"
        let supported = ["en", "zh-Hans", "ja", "ko", "de", "es", "it", "ru"]
        return supported.first(where: { preferred.hasPrefix($0) }) ?? "en"
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            reloadBundle()
        }
    }

    @Published private(set) var bundle: Bundle = .main
    @Published var languageRefreshId = UUID()

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode")
            .flatMap { AppearanceMode(rawValue: $0) } ?? .system
        let savedLang = UserDefaults.standard.string(forKey: "appLanguage")
            .flatMap { AppLanguage(rawValue: $0) } ?? .system

        self.appearanceMode = savedMode
        self.appLanguage = savedLang

        applyAppearance()
        reloadBundle()
    }

    func applyAppearance() {
        NSApp.appearance = appearanceMode.nsAppearance
    }

    private func reloadBundle() {
        let code = appLanguage.effectiveCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
        languageRefreshId = UUID()
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    var currentAppVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let version, let build, !build.isEmpty, build != version {
            return "\(version) (\(build))"
        }
        return version ?? "1.0.0"
    }
}

func L(_ key: String) -> String {
    AppState.shared.localized(key)
}
