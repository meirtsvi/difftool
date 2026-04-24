import Foundation
import SwiftUI

@MainActor
class FileDiffViewModel: ObservableObject {
    @Published var diffResult: FileDiffResult?
    @Published var currentHunkIndex: Int = 0
    @Published var isLoading = false
    @Published var hasUnsavedLeft = false
    @Published var hasUnsavedRight = false
    // Bumped whenever the view should scroll to the current hunk even if
    // `currentHunkIndex` didn't change (e.g., after a copy collapses the
    // current hunk and the next hunk slides into the same index).
    @Published private(set) var scrollRequestID: Int = 0

    var hasUnsavedChanges: Bool { hasUnsavedLeft || hasUnsavedRight }

    let leftFolderURL: URL
    let rightFolderURL: URL
    let file: FileComparisonResult

    var leftFileURL: URL { leftFolderURL.appendingPathComponent(file.relativePath) }
    var rightFileURL: URL { rightFolderURL.appendingPathComponent(file.relativePath) }

    var hunkCount: Int { diffResult?.hunks.count ?? 0 }

    private var leftModifiedText: String? = nil
    private var rightModifiedText: String? = nil

    init(file: FileComparisonResult, leftFolder: URL, rightFolder: URL) {
        self.file = file
        self.leftFolderURL = leftFolder
        self.rightFolderURL = rightFolder
    }

    func computeDiff(resetHunkIndex: Bool = true) {
        isLoading = true
        diffResult = DiffEngine.diff(leftURL: leftFileURL, rightURL: rightFileURL,
                                     leftOverride: leftModifiedText, rightOverride: rightModifiedText)
        let newCount = diffResult?.hunks.count ?? 0
        if resetHunkIndex || newCount == 0 {
            currentHunkIndex = 0
        } else {
            // Keep the same index; the hunk that was current is now resolved,
            // so this index points at what used to be the next hunk.
            currentHunkIndex = min(currentHunkIndex, newCount - 1)
        }
        isLoading = false
    }

    func nextHunk() {
        guard let diff = diffResult, !diff.hunks.isEmpty else { return }
        currentHunkIndex = min(currentHunkIndex + 1, diff.hunks.count - 1)
    }

    func previousHunk() {
        currentHunkIndex = max(currentHunkIndex - 1, 0)
    }

    func copyLeftToRight() {
        guard let diff = diffResult else { return }
        let currentText = rightModifiedText ?? (try? String(contentsOf: rightFileURL, encoding: diff.rightEncoding)) ?? ""
        let destLines = currentText.components(separatedBy: "\n")
        if let newLines = DiffEngine.applyHunkInMemory(destLines: destLines, diffResult: diff, hunkIndex: currentHunkIndex, direction: .leftToRight) {
            rightModifiedText = newLines.joined(separator: "\n")
            hasUnsavedRight = true
            computeDiff(resetHunkIndex: false)
            scrollRequestID &+= 1
        }
    }

    func copyRightToLeft() {
        guard let diff = diffResult else { return }
        let currentText = leftModifiedText ?? (try? String(contentsOf: leftFileURL, encoding: diff.leftEncoding)) ?? ""
        let destLines = currentText.components(separatedBy: "\n")
        if let newLines = DiffEngine.applyHunkInMemory(destLines: destLines, diffResult: diff, hunkIndex: currentHunkIndex, direction: .rightToLeft) {
            leftModifiedText = newLines.joined(separator: "\n")
            hasUnsavedLeft = true
            computeDiff(resetHunkIndex: false)
            scrollRequestID &+= 1
        }
    }

    func saveLeft() {
        guard let diff = diffResult, let text = leftModifiedText else { return }
        try? text.write(to: leftFileURL, atomically: true, encoding: diff.leftEncoding)
        leftModifiedText = nil
        hasUnsavedLeft = false
    }

    func saveRight() {
        guard let diff = diffResult, let text = rightModifiedText else { return }
        try? text.write(to: rightFileURL, atomically: true, encoding: diff.rightEncoding)
        rightModifiedText = nil
        hasUnsavedRight = false
    }

    func saveChanges() {
        saveLeft()
        saveRight()
    }

    func discardChanges() {
        leftModifiedText = nil
        rightModifiedText = nil
        hasUnsavedLeft = false
        hasUnsavedRight = false
        computeDiff()
    }
}
