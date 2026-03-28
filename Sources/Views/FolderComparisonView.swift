import SwiftUI

struct FolderComparisonView: View {
    @ObservedObject var viewModel: FolderComparisonViewModel

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if viewModel.results.isEmpty && !viewModel.isComparing {
                emptyState
            } else {
                fileList
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            if viewModel.leftFolderURL != nil && viewModel.rightFolderURL != nil {
                Task { await viewModel.compare() }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                folderSelector(label: "Left:", path: viewModel.leftFolderURL?.path ?? "No folder selected", isLeft: true)
                folderSelector(label: "Right:", path: viewModel.rightFolderURL?.path ?? "No folder selected", isLeft: false)
            }
            .padding(.horizontal, 12)

            HStack(spacing: 16) {
                Picker("Filter:", selection: $viewModel.filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 500)

                Picker("Sort:", selection: $viewModel.sortMode) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 140)

                Spacer()

                if viewModel.isComparing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.leftFolderURL == nil || viewModel.rightFolderURL == nil)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: viewModel.filterMode) { _, _ in viewModel.applyFilterAndSort() }
        .onChange(of: viewModel.sortMode) { _, _ in viewModel.applyFilterAndSort() }
    }

    private func folderSelector(label: String, path: String, isLeft: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(.body, weight: .semibold))
                .frame(width: 40, alignment: .trailing)
            Text(path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(4)
            Button("...") {
                viewModel.selectFolder(isLeft: isLeft)
            }
            .frame(width: 36)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select two folders to compare")
                .font(.title2)
                .foregroundColor(.secondary)
            HStack(spacing: 20) {
                Button("Select Left Folder...") { viewModel.selectFolder(isLeft: true) }
                Button("Select Right Folder...") { viewModel.selectFolder(isLeft: false) }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                fileListHeader
                ForEach(viewModel.filteredResults) { file in
                    FileComparisonRow(file: file, isSelected: viewModel.selectedFile == file)
                        .onTapGesture {
                            viewModel.selectedFile = file
                        }
                        .onTapGesture(count: 2) {
                            viewModel.openFileDiff(for: file)
                        }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onKeyPress(.return) {
            if let selected = viewModel.selectedFile {
                viewModel.openFileDiff(for: selected)
                return .handled
            }
            return .ignored
        }
    }

    private var fileListHeader: some View {
        HStack(spacing: 0) {
            Text("Status")
                .frame(width: 80, alignment: .center)
            Divider().frame(height: 20)
            Text("File Path")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            Divider().frame(height: 20)
            Text("Left Size")
                .frame(width: 90, alignment: .trailing)
            Divider().frame(height: 20)
            Text("Right Size")
                .frame(width: 90, alignment: .trailing)
            Divider().frame(height: 20)
            Text("Modified")
                .frame(width: 140, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            Label("\(viewModel.identicalCount) identical", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("\(viewModel.modifiedCount) modified", systemImage: "pencil.circle.fill")
                .foregroundColor(.red)
            Label("\(viewModel.leftOnlyCount) left only", systemImage: "arrow.left.circle.fill")
                .foregroundColor(.orange)
            Label("\(viewModel.rightOnlyCount) right only", systemImage: "arrow.right.circle.fill")
                .foregroundColor(.blue)
            Spacer()
            Text("\(viewModel.filteredResults.count) of \(viewModel.results.count) files shown")
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - File Row

struct FileComparisonRow: View {
    let file: FileComparisonResult
    let isSelected: Bool

    var statusColor: Color {
        switch file.status {
        case .identical: return .green
        case .modified: return .red
        case .leftOnly: return .orange
        case .rightOnly: return .blue
        }
    }

    var statusIcon: String {
        switch file.status {
        case .identical: return "checkmark.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .leftOnly: return "arrow.left.circle.fill"
        case .rightOnly: return "arrow.right.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 80, alignment: .center)

            Text(file.relativePath)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            Text(file.leftSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "-")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)

            Text(file.rightSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "-")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)

            Text(file.displayDate)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}
