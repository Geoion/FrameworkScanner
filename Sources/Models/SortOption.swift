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
