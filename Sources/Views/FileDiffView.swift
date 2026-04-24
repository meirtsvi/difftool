import SwiftUI

struct FileDiffView: View {
    @ObservedObject var viewModel: FileDiffViewModel
    let onDismiss: () -> Void

    @AppStorage("diffWordWrap") private var wordWrap = false
    @State private var showDismissAlert = false

    private func attemptDismiss() {
        if viewModel.hasUnsavedChanges {
            showDismissAlert = true
        } else {
            onDismiss()
        }
    }

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
        .alert("Save changes?", isPresented: $showDismissAlert) {
            Button("Save") { viewModel.saveChanges(); onDismiss() }
            Button("Discard", role: .destructive) { viewModel.discardChanges(); onDismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(unsavedChangesMessage)
        }
    }

    private var unsavedChangesMessage: String {
        switch (viewModel.hasUnsavedLeft, viewModel.hasUnsavedRight) {
        case (true, true):
            return "You have unsaved changes in both files. Save them before leaving?"
        case (true, false):
            return "You have unsaved changes in the left file. Save them before leaving?"
        case (false, true):
            return "You have unsaved changes in the right file. Save them before leaving?"
        case (false, false):
            return "You have unsaved changes. Save them before leaving?"
        }
    }

    // MARK: - Toolbar

    private var diffToolbar: some View {
        HStack(spacing: 12) {
            Button(action: attemptDismiss) {
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

            Divider().frame(height: 24)

            Button(action: { viewModel.saveLeft() }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Left")
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!viewModel.hasUnsavedLeft)
            .help("Save changes to left file (⇧⌘S)")

            Button(action: { viewModel.saveRight() }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Right")
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!viewModel.hasUnsavedRight)
            .help("Save changes to right file (⌘S)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Synced Diff (single ScrollView)

    private func syncedDiffView(diff: FileDiffResult) -> some View {
        syncedDiffViewBody(diff: diff)
            .environment(\.layoutDirection, .leftToRight)
    }

    private func syncedDiffViewBody(diff: FileDiffResult) -> some View {
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

            HStack(spacing: 0) {
                // Outer vertical-only scroll keeps panes synchronized vertically.
                // Each pane has its own inner horizontal ScrollView so horizontal
                // overflow shows a per-pane scrollbar only where needed.
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        HStack(spacing: 0) {
                            paneView(diff: diff, side: .left)
                                .frame(minWidth: 400, maxWidth: .infinity)

                            centerConnectorColumn(diff: diff)
                                .frame(width: centerW)

                            paneView(diff: diff, side: .right)
                                .frame(minWidth: 400, maxWidth: .infinity)
                        }
                    }
                    .onChange(of: viewModel.currentHunkIndex) { _, newValue in
                        if newValue < diff.hunks.count {
                            let hunk = diff.hunks[newValue]
                            withAnimation { proxy.scrollTo("line\(hunk.startIndex)", anchor: .center) }
                        }
                    }
                    .onChange(of: viewModel.scrollRequestID) { _, _ in
                        // Fires after copy operations, when the current hunk
                        // collapses and the next one slides into the same index.
                        if let currentDiff = viewModel.diffResult,
                           viewModel.currentHunkIndex < currentDiff.hunks.count {
                            let hunk = currentDiff.hunks[viewModel.currentHunkIndex]
                            withAnimation { proxy.scrollTo("line\(hunk.startIndex)", anchor: .center) }
                        }
                    }
                }

                // Diff overview map
                DiffMapView(hunks: diff.hunks, totalLines: diff.lines.count, currentHunkIndex: viewModel.currentHunkIndex)
                    .frame(width: 12)
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

    // MARK: - Panes

    private func paneView(diff: FileDiffResult, side: DiffSide) -> some View {
        HStack(spacing: 0) {
            // Fixed gutter column — not horizontally scrollable.
            VStack(spacing: 0) {
                ForEach(Array(diff.lines.enumerated()), id: \.offset) { index, line in
                    gutterCell(line: line, index: index, side: side)
                }
            }

            // Content column — per-pane horizontal scroll when word wrap is off.
            Group {
                if wordWrap {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.lines.enumerated()), id: \.offset) { index, line in
                            lineContentCell(line: line, index: index, side: side)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(diff.lines.enumerated()), id: \.offset) { index, line in
                                lineContentCell(line: line, index: index, side: side)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func gutterCell(line: DiffLine, index: Int, side: DiffSide) -> some View {
        let lineNumber = side == .left ? line.leftLineNumber : line.rightLineNumber
        let bg = side == .left ? leftBg(line, index) : rightBg(line, index)
        let view = Text(lineNumber.map { String($0) } ?? "")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: gutterW, alignment: .trailing)
            .padding(.trailing, 6)
            .frame(height: lineH)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            .background(bg)
        if side == .right {
            return AnyView(view.id("line\(index)"))
        }
        return AnyView(view)
    }

    private func lineContentCell(line: DiffLine, index: Int, side: DiffSide) -> some View {
        let text = side == .left ? line.leftText : line.rightText
        let bg = side == .left ? leftBg(line, index) : rightBg(line, index)
        return Group {
            if let text {
                if line.type == .modified, let changes = line.inlineChanges, !changes.isEmpty {
                    buildHighlightedText(text: text, changes: changes, side: side)
                } else {
                    Text(text)
                }
            } else {
                Text("")
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .lineLimit(wordWrap ? nil : 1)
        .fixedSize(horizontal: !wordWrap, vertical: false)
        .frame(maxWidth: wordWrap ? .infinity : nil, alignment: .leading)
        .frame(height: lineH, alignment: .leading)
        .padding(.horizontal, 4)
        .background(bg)
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

// MARK: - Diff Map (overview ruler)

struct DiffMapView: View {
    let hunks: [DiffHunk]
    let totalLines: Int
    let currentHunkIndex: Int

    var body: some View {
        Canvas { context, size in
            let total = max(totalLines, 1)
            for (i, hunk) in hunks.enumerated() {
                let yStart = CGFloat(hunk.startIndex) / CGFloat(total) * size.height
                let yEnd = CGFloat(hunk.endIndex + 1) / CGFloat(total) * size.height
                let h = max(yEnd - yStart, 2)
                let color = i == currentHunkIndex ? Color.accentColor : hunkColor(hunk)
                context.fill(Path(CGRect(x: 1, y: yStart, width: size.width - 2, height: h)),
                             with: .color(color.opacity(i == currentHunkIndex ? 0.9 : 0.6)))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    private func hunkColor(_ hunk: DiffHunk) -> Color {
        let types = Set(hunk.lines.map { $0.type })
        if types.contains(.modified) { return .red }
        if types.contains(.added) { return .blue }
        return .orange
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
