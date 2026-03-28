import Foundation

enum FileStatus: String, CaseIterable, Comparable {
    case identical
    case modified
    case leftOnly
    case rightOnly

    var displayName: String {
        switch self {
        case .identical: return "Identical"
        case .modified: return "Modified"
        case .leftOnly: return "Left Only"
        case .rightOnly: return "Right Only"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .modified: return 0
        case .leftOnly: return 1
        case .rightOnly: return 2
        case .identical: return 3
        }
    }

    static func < (lhs: FileStatus, rhs: FileStatus) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum FilterMode: String, CaseIterable {
    case all = "All Files"
    case differencesOnly = "Differences Only"
    case leftOnly = "Left Only"
    case rightOnly = "Right Only"
}

enum SortMode: String, CaseIterable {
    case name = "Name"
    case status = "Status"
    case date = "Date"
    case size = "Size"
}

struct FileComparisonResult: Identifiable, Hashable {
    let id = UUID()
    let relativePath: String
    let fileName: String
    let status: FileStatus
    let leftSize: Int64?
    let rightSize: Int64?
    let leftDate: Date?
    let rightDate: Date?
    let isDirectory: Bool

    var displaySize: String {
        let size = leftSize ?? rightSize ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var displayDate: String {
        let date = leftDate ?? rightDate
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileComparisonResult, rhs: FileComparisonResult) -> Bool {
        lhs.id == rhs.id
    }
}
