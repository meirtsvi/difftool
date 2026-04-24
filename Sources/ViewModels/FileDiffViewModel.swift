import Foundation
import SwiftUI

@MainActor
class FileDiffViewModel: ObservableObject {
    @Published var diffResult: FileDiffResult?
    @Published var currentHunkIndex: Int = 0
    @Published var isLoading = false
    @Published var hasUnsavedChanges = false

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

    func computeDiff() {
        isLoading = true
        diffResult = DiffEngine.diff(leftURL: leftFileURL, rightURL: rightFileURL,
                                     leftOverride: leftModifiedText, rightOverride: rightModifiedText)
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
        let currentText = rightModifiedText ?? (try? String(contentsOf: rightFileURL, encoding: diff.rightEncoding)) ?? ""
        let destLines = currentText.components(separatedBy: "\n")
        if let newLines = DiffEngine.applyHunkInMemory(destLines: destLines, diffResult: diff, hunkIndex: currentHunkIndex, direction: .leftToRight) {
            rightModifiedText = newLines.joined(separator: "\n")
            hasUnsavedChanges = true
            computeDiff()
        }
    }

    func copyRightToLeft() {
        guard let diff = diffResult else { return }
        let currentText = leftModifiedText ?? (try? String(contentsOf: leftFileURL, encoding: diff.leftEncoding)) ?? ""
        let destLines = currentText.components(separatedBy: "\n")
        if let newLines = DiffEngine.applyHunkInMemory(destLines: destLines, diffResult: diff, hunkIndex: currentHunkIndex, direction: .rightToLeft) {
            leftModifiedText = newLines.joined(separator: "\n")
            hasUnsavedChanges = true
            computeDiff()
        }
    }

    func saveChanges() {
        guard let diff = diffResult else { return }
        if let text = leftModifiedText {
            try? text.write(to: leftFileURL, atomically: true, encoding: diff.leftEncoding)
            leftModifiedText = nil
        }
        if let text = rightModifiedText {
            try? text.write(to: rightFileURL, atomically: true, encoding: diff.rightEncoding)
            rightModifiedText = nil
        }
        hasUnsavedChanges = false
    }

    func discardChanges() {
        leftModifiedText = nil
        rightModifiedText = nil
        hasUnsavedChanges = false
        computeDiff()
    }
}
