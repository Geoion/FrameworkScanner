import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()

    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
    @AppStorage("appLanguage") var appLanguage: AppLanguage = .system

    var effectiveColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }
}
