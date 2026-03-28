import SwiftUI

struct FileDiffView: View {
    @ObservedObject var viewModel: FileDiffViewModel
    let onDismiss: () -> Void
    
    @State private var wordWrap = false

    private let lineH: CGFloat = 20
    private let gutterW: CGFloat = 44
    private let centerW: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            diffToolbar
            Divider()
            if viewModel.isLoading {
                ProgressView("Computing diff...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = viewModel.diffResult {
                if diff.isBinary {
                    binaryFileView
                } else {
                    syncedDiffView(diff: diff)
                }
            } else {
                Text("No diff result")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            diffStatusBar
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { viewModel.computeDiff() }
    }

    // MARK: - Toolbar

    private var diffToolbar: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .keyboardShortcut(.escape, modifiers: [])

            Divider().frame(height: 24)

            Text(viewModel.file.relativePath)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Toggle(isOn: $wordWrap) {
                Image(systemName: "text.word.spacing")
            }
            .toggleStyle(.button)
            .help("Word Wrap")

            Divider().frame(height: 24)

            HStack(spacing: 8) {
                Button(action: { viewModel.previousHunk() }) {
                    Image(systemName: "chevron.up")
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(viewModel.currentHunkIndex <= 0)

                Text("\(viewModel.hunkCount > 0 ? viewModel.currentHunkIndex + 1 : 0) / \(viewModel.hunkCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 60)

                Button(action: { viewModel.nextHunk() }) {
                    Image(systemName: "chevron.down")
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(viewModel.currentHunkIndex >= viewModel.hunkCount - 1)
            }

            Divider().frame(height: 24)

            Button(action: { viewModel.copyRightToLeft() }) {
                Image(systemName: "arrow.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help("Copy right → left")

            Button(action: { viewModel.copyLeftToRight() }) {
                Image(systemName: "arrow.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .help("Copy left → right")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Synced Diff (single ScrollView)

    private func syncedDiffView(diff: FileDiffResult) -> some View {
        VStack(spacing: 0) {
            // Headers
            HStack(spacing: 0) {
                paneHeader(title: viewModel.leftFileURL.lastPathComponent, color: .orange)
                Divider().frame(width: centerW)
                    .background(Color(nsColor: .controlBackgroundColor))
                paneHeader(title: viewModel.rightFileURL.lastPathComponent, color: .blue)
            }
            .frame(height: 28)
            Divider()

            // Single scroll view for both panes — guarantees sync
            ScrollViewReader { proxy in
                ScrollView(wordWrap ? [.vertical] : [.vertical, .horizontal]) {
                    ZStack(alignment: .top) {
                        HStack(spacing: 0) {
                            // Left pane
                            VStack(spacing: 0) {
                                ForEach(Array(diff.lines.enumerated()), id: \.offset) { index, line in
                                    leftLineRow(line: line, index: index)
                                }
                            }
                            .frame(minWidth: 400)

                            // Center connector column
                            centerConnectorColumn(diff: diff)
                                .frame(width: centerW)

                            // Right pane
                            VStack(spacing: 0) {
                                ForEach(Array(diff.lines.enumerated()), id: \.offset) { index, line in
                                    rightLineRow(line: line, index: index)
                                        .id("line\(index)")
                                }
                            }
                            .frame(minWidth: 400)
                        }
                    }
                }
                .onChange(of: viewModel.currentHunkIndex) { _, newValue in
                    if newValue < diff.hunks.count {
                        let hunk = diff.hunks[newValue]
                        withAnimation { proxy.scrollTo("line\(hunk.startIndex)", anchor: .center) }
                    }
                }
            }
        }
    }

    // MARK: - Center Connector Column

    private func centerConnectorColumn(diff: FileDiffResult) -> some View {
        Canvas { context, size in
            let lx: CGFloat = 0
            let rx: CGFloat = size.width

            for (i, hunk) in diff.hunks.enumerated() {
                let topY = CGFloat(hunk.startIndex) * lineH
                let bottomY = CGFloat(hunk.endIndex + 1) * lineH

                let isCurrentHunk = i == viewModel.currentHunkIndex
                let color: Color = isCurrentHunk ? .accentColor : .gray.opacity(0.5)

                // Draw connecting shape (trapezoid between left and right)
                var path = Path()
                path.move(to: CGPoint(x: lx, y: topY))
                path.addLine(to: CGPoint(x: rx, y: topY))
                path.addLine(to: CGPoint(x: rx, y: bottomY))
                path.addLine(to: CGPoint(x: lx, y: bottomY))
                path.closeSubpath()

                context.fill(path, with: .color(color.opacity(0.12)))
                context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 1)

                // Draw merge arrow buttons
                let midY = (topY + bottomY) / 2
                let arrowSize: CGFloat = 6

                // Right arrow (left → right)
                var rightArrow = Path()
                rightArrow.move(to: CGPoint(x: size.width / 2 + 2, y: midY - 8 - arrowSize))
                rightArrow.addLine(to: CGPoint(x: size.width / 2 + 2 + arrowSize, y: midY - 8))
                rightArrow.addLine(to: CGPoint(x: size.width / 2 + 2, y: midY - 8 + arrowSize))
                rightArrow.closeSubpath()
                context.fill(rightArrow, with: .color(.orange.opacity(0.8)))

                // Left arrow (right → left)
                var leftArrow = Path()
                leftArrow.move(to: CGPoint(x: size.width / 2 - 2, y: midY + 8 - arrowSize))
                leftArrow.addLine(to: CGPoint(x: size.width / 2 - 2 - arrowSize, y: midY + 8))
                leftArrow.addLine(to: CGPoint(x: size.width / 2 - 2, y: midY + 8 + arrowSize))
                leftArrow.closeSubpath()
                context.fill(leftArrow, with: .color(.blue.opacity(0.8)))
            }
        }
        .frame(height: CGFloat(diff.lines.count) * lineH)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.15))
    }

    // MARK: - Pane Header

    private func paneHeader(title: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Line Rows

    private func leftLineRow(line: DiffLine, index: Int) -> some View {
        HStack(spacing: 0) {
            Text(line.leftLineNumber.map { String($0) } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: gutterW, alignment: .trailing)
                .padding(.trailing, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Group {
                if let text = line.leftText {
                    if line.type == .modified, let changes = line.inlineChanges, !changes.isEmpty {
                        buildHighlightedText(text: text, changes: changes, side: .left)
                    } else {
                        Text(text)
                    }
                } else {
                    Text("")
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .if(!wordWrap) { $0.fixedSize(horizontal: true, vertical: false) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .frame(height: lineH)
        .background(leftBg(line, index))
    }

    private func rightLineRow(line: DiffLine, index: Int) -> some View {
        HStack(spacing: 0) {
            Text(line.rightLineNumber.map { String($0) } ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: gutterW, alignment: .trailing)
                .padding(.trailing, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Group {
                if let text = line.rightText {
                    if line.type == .modified, let changes = line.inlineChanges, !changes.isEmpty {
                        buildHighlightedText(text: text, changes: changes, side: .right)
                    } else {
                        Text(text)
                    }
                } else {
                    Text("")
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .if(!wordWrap) { $0.fixedSize(horizontal: true, vertical: false) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .frame(height: lineH)
        .background(rightBg(line, index))
    }

    // MARK: - Backgrounds

    private func leftBg(_ line: DiffLine, _ index: Int) -> Color {
        let hunk = isInCurrentHunk(lineIndex: index) ? Color.accentColor.opacity(0.06) : Color.clear
        switch line.type {
        case .unchanged: return hunk
        case .removed: return Color.orange.opacity(0.15).blend(with: hunk)
        case .modified: return Color.red.opacity(0.12).blend(with: hunk)
        case .added: return Color(nsColor: .controlBackgroundColor).opacity(0.2).blend(with: hunk)
        }
    }

    private func rightBg(_ line: DiffLine, _ index: Int) -> Color {
        let hunk = isInCurrentHunk(lineIndex: index) ? Color.accentColor.opacity(0.06) : Color.clear
        switch line.type {
        case .unchanged: return hunk
        case .added: return Color.blue.opacity(0.15).blend(with: hunk)
        case .modified: return Color.red.opacity(0.12).blend(with: hunk)
        case .removed: return Color(nsColor: .controlBackgroundColor).opacity(0.2).blend(with: hunk)
        }
    }

    // MARK: - Inline Highlighting

    private func buildHighlightedText(text: String, changes: [InlineChange], side: DiffSide) -> Text {
        let highlightColor: Color = side == .left ? .orange.opacity(0.35) : .blue.opacity(0.35)
        var result = AttributedString(text)
        for change in changes {
            let stringRange = side == .left ? change.leftRange : change.rightRange
            guard let stringRange else { continue }
            let startOffset = text.distance(from: text.startIndex, to: stringRange.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: stringRange.upperBound)
            guard startOffset < result.characters.count, endOffset <= result.characters.count else { continue }
            let attrStart = result.characters.index(result.startIndex, offsetBy: startOffset)
            let attrEnd = result.characters.index(result.startIndex, offsetBy: endOffset)
            result[attrStart..<attrEnd].backgroundColor = highlightColor
            result[attrStart..<attrEnd].font = .system(size: 12, design: .monospaced).bold()
        }
        return Text(result)
    }

    // MARK: - Helpers

    private func isInCurrentHunk(lineIndex: Int) -> Bool {
        guard let diff = viewModel.diffResult,
              viewModel.currentHunkIndex < diff.hunks.count else { return false }
        let hunk = diff.hunks[viewModel.currentHunkIndex]
        return lineIndex >= hunk.startIndex && lineIndex <= hunk.endIndex
    }

    private func hunkIndexForLine(lineIndex: Int) -> Int? {
        guard let diff = viewModel.diffResult else { return nil }
        for (i, hunk) in diff.hunks.enumerated() {
            if lineIndex >= hunk.startIndex && lineIndex <= hunk.endIndex { return i }
        }
        return nil
    }

    // MARK: - Binary / Status

    private var binaryFileView: some View {
        VStack {
            Spacer()
            Image(systemName: "doc.fill").font(.system(size: 48)).foregroundColor(.secondary)
            Text("Binary files differ").font(.title2).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diffStatusBar: some View {
        HStack {
            if let diff = viewModel.diffResult {
                Text("\(diff.hunks.count) difference\(diff.hunks.count == 1 ? "" : "s") found")
                Spacer()
                Text("\(diff.lines.count) lines")
            } else { Spacer() }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Helpers

enum DiffSide { case left, right }

extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension Color {
    func blend(with other: Color) -> Color {
        // Simple overlay approximation
        other == .clear ? self : self
    }
}
