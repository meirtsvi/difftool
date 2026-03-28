import SwiftUI

struct ContentView: View {
    @StateObject var folderViewModel: FolderComparisonViewModel

    var body: some View {
        Group {
            if folderViewModel.showingFileDiff,
               let diffVM = folderViewModel.fileDiffViewModel {
                FileDiffView(
                    viewModel: diffVM,
                    onDismiss: {
                        folderViewModel.showingFileDiff = false
                        folderViewModel.fileDiffViewModel = nil
                    }
                )
            } else {
                FolderComparisonView(viewModel: folderViewModel)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        // Keyboard shortcuts
        .keyboardShortcut(for: .filter1) { folderViewModel.filterMode = .all; folderViewModel.applyFilterAndSort() }
        .keyboardShortcut(for: .filter2) { folderViewModel.filterMode = .differencesOnly; folderViewModel.applyFilterAndSort() }
        .keyboardShortcut(for: .filter3) { folderViewModel.filterMode = .leftOnly; folderViewModel.applyFilterAndSort() }
        .keyboardShortcut(for: .filter4) { folderViewModel.filterMode = .rightOnly; folderViewModel.applyFilterAndSort() }
    }
}

// MARK: - Keyboard Shortcut Modifier

enum AppShortcut {
    case filter1, filter2, filter3, filter4
}

extension View {
    func keyboardShortcut(for shortcut: AppShortcut, action: @escaping () -> Void) -> some View {
        switch shortcut {
        case .filter1:
            return AnyView(self.background(
                Button(action: action) { EmptyView() }
                    .keyboardShortcut("1", modifiers: .command)
                    .hidden()
            ))
        case .filter2:
            return AnyView(self.background(
                Button(action: action) { EmptyView() }
                    .keyboardShortcut("2", modifiers: .command)
                    .hidden()
            ))
        case .filter3:
            return AnyView(self.background(
                Button(action: action) { EmptyView() }
                    .keyboardShortcut("3", modifiers: .command)
                    .hidden()
            ))
        case .filter4:
            return AnyView(self.background(
                Button(action: action) { EmptyView() }
                    .keyboardShortcut("4", modifiers: .command)
                    .hidden()
            ))
        }
    }
}
