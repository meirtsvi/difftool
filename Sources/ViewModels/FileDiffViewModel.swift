import Foundation
import SwiftUI

@MainActor
class FileDiffViewModel: ObservableObject {
    @Published var diffResult: FileDiffResult?
    @Published var currentHunkIndex: Int = 0
    @Published var isLoading = false

    let leftFolderURL: URL
    let rightFolderURL: URL
    let file: FileComparisonResult

    var leftFileURL: URL { leftFolderURL.appendingPathComponent(file.relativePath) }
    var rightFileURL: URL { rightFolderURL.appendingPathComponent(file.relativePath) }

    var hunkCount: Int { diffResult?.hunks.count ?? 0 }

    init(file: FileComparisonResult, leftFolder: URL, rightFolder: URL) {
        self.file = file
        self.leftFolderURL = leftFolder
        self.rightFolderURL = rightFolder
    }

    func computeDiff() {
        isLoading = true
        let result = DiffEngine.diff(leftURL: leftFileURL, rightURL: rightFileURL)
        diffResult = result
        currentHunkIndex = 0
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
        if DiffEngine.copyLeftToRight(leftURL: leftFileURL, rightURL: rightFileURL, diffResult: diff, hunkIndex: currentHunkIndex) {
            computeDiff()
        }
    }

    func copyRightToLeft() {
        guard let diff = diffResult else { return }
        if DiffEngine.copyRightToLeft(leftURL: leftFileURL, rightURL: rightFileURL, diffResult: diff, hunkIndex: currentHunkIndex) {
            computeDiff()
        }
    }
}
