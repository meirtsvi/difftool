import Foundation

enum DiffLineType {
    case unchanged
    case added
    case removed
    case modified
}

struct DiffLine: Identifiable {
    let id = UUID()
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let leftText: String?
    let rightText: String?
    let type: DiffLineType
    let inlineChanges: [InlineChange]?
}

struct InlineChange {
    let leftRange: Range<String.Index>?
    let rightRange: Range<String.Index>?
}

struct DiffHunk: Identifiable {
    let id = UUID()
    let startIndex: Int
    let endIndex: Int
    let lines: [DiffLine]
}

struct FileDiffResult {
    let leftPath: URL
    let rightPath: URL
    let lines: [DiffLine]
    let hunks: [DiffHunk]
    let isBinary: Bool
    let leftEncoding: String.Encoding
    let rightEncoding: String.Encoding

    var hasDifferences: Bool {
        !hunks.isEmpty
    }
}
