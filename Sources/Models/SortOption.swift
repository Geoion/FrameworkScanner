import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case date = "Date"
    case framework = "Framework"

    var id: String { rawValue }
}

enum SortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = (self == .ascending) ? .descending : .ascending
    }
}

enum AppSource: String, CaseIterable, Identifiable {
    case user = "User"
    case system = "System"
    case homebrew = "Homebrew"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .user: return "person.fill"
        case .system: return "apple.logo"
        case .homebrew: return "mug.fill"
        }
    }

    func matches(_ app: AppInfo) -> Bool {
        switch self {
        case .user: return !app.isSystemApp && !app.isFromHomebrew
        case .system: return app.isSystemApp
        case .homebrew: return app.isFromHomebrew
        }
    }
}
