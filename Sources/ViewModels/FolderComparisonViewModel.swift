import Foundation
import SwiftUI

@MainActor
class FolderComparisonViewModel: ObservableObject {
    @Published var leftFolderURL: URL?
    @Published var rightFolderURL: URL?
    @Published var results: [FileComparisonResult] = []
    @Published var filteredResults: [FileComparisonResult] = []
    @Published var selectedFile: FileComparisonResult?
    @Published var isComparing = false
    @Published var filterMode: FilterMode = .all
    @Published var sortMode: SortMode = .name
    @Published var showingFileDiff = false
    @Published var searchText = ""

    var identicalCount: Int { results.filter { $0.status == .identical }.count }
    var modifiedCount: Int { results.filter { $0.status == .modified }.count }
    var leftOnlyCount: Int { results.filter { $0.status == .leftOnly }.count }
    var rightOnlyCount: Int { results.filter { $0.status == .rightOnly }.count }

    init(leftPath: String? = nil, rightPath: String? = nil) {
        if let leftPath {
            self.leftFolderURL = URL(fileURLWithPath: leftPath)
        }
        if let rightPath {
            self.rightFolderURL = URL(fileURLWithPath: rightPath)
        }
    }

    func compare() async {
        guard let left = leftFolderURL, let right = rightFolderURL else { return }
        isComparing = true
        results = await FolderComparisonEngine.compare(leftFolder: left, rightFolder: right)
        applyFilterAndSort()
        isComparing = false
    }

    func refresh() {
        Task { await compare() }
    }

    func applyFilterAndSort() {
        var filtered = results

        // Apply filter
        switch filterMode {
        case .all:
            break
        case .differencesOnly:
            filtered = filtered.filter { $0.status == .modified }
        case .leftOnly:
            filtered = filtered.filter { $0.status == .leftOnly }
        case .rightOnly:
            filtered = filtered.filter { $0.status == .rightOnly }
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.relativePath.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply sort
        switch sortMode {
        case .name:
            filtered.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        case .status:
            filtered.sort { $0.status < $1.status }
        case .date:
            filtered.sort { ($0.leftDate ?? .distantPast) > ($1.leftDate ?? .distantPast) }
        case .size:
            filtered.sort { ($0.leftSize ?? 0) > ($1.leftSize ?? 0) }
        }

        filteredResults = filtered
    }

    func selectFolder(isLeft: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = isLeft ? "Select left folder" : "Select right folder"

        if panel.runModal() == .OK, let url = panel.url {
            if isLeft {
                leftFolderURL = url
            } else {
                rightFolderURL = url
            }
            if leftFolderURL != nil && rightFolderURL != nil {
                Task { await compare() }
            }
        }
    }

    @Published var fileDiffViewModel: FileDiffViewModel?

    func openFileDiff(for file: FileComparisonResult) {
        guard file.status != .identical, !file.isDirectory else { return }
        guard let left = leftFolderURL, let right = rightFolderURL else { return }
        selectedFile = file
        fileDiffViewModel = FileDiffViewModel(file: file, leftFolder: left, rightFolder: right)
        showingFileDiff = true
    }
}
