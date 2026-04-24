import Foundation

class DiffEngine {

    // MARK: - Public API

    static func diff(leftURL: URL, rightURL: URL, leftOverride: String? = nil, rightOverride: String? = nil) -> FileDiffResult {
        let leftExists = FileManager.default.fileExists(atPath: leftURL.path)
        let rightExists = FileManager.default.fileExists(atPath: rightURL.path)

        let (leftData, leftEncoding) = leftExists ? readFile(at: leftURL) : (Data(), .utf8 as String.Encoding)
        let (rightData, rightEncoding) = rightExists ? readFile(at: rightURL) : (Data(), .utf8 as String.Encoding)

        if leftOverride == nil && rightOverride == nil {
            if (leftExists && isBinary(leftData)) || (rightExists && isBinary(rightData)) {
                return FileDiffResult(
                    leftPath: leftURL, rightPath: rightURL,
                    lines: [], hunks: [], isBinary: true,
                    leftEncoding: leftEncoding, rightEncoding: rightEncoding
                )
            }
        }

        let leftText = leftOverride ?? (leftExists ? (String(data: leftData, encoding: leftEncoding) ?? "") : "")
        let rightText = rightOverride ?? (rightExists ? (String(data: rightData, encoding: rightEncoding) ?? "") : "")

        // Handle single-side files
        if !leftExists && rightExists {
            let rightLines = rightText.components(separatedBy: "\n")
            var diffLines: [DiffLine] = []
            for (i, line) in rightLines.enumerated() {
                diffLines.append(DiffLine(
                    leftLineNumber: nil, rightLineNumber: i + 1,
                    leftText: nil, rightText: line,
                    type: .added, inlineChanges: nil
                ))
            }
            let hunks = diffLines.isEmpty ? [] : [DiffHunk(startIndex: 0, endIndex: diffLines.count - 1, lines: diffLines)]
            return FileDiffResult(
                leftPath: leftURL, rightPath: rightURL,
                lines: diffLines, hunks: hunks, isBinary: false,
                leftEncoding: leftEncoding, rightEncoding: rightEncoding
            )
        }

        if leftExists && !rightExists {
            let leftLines = leftText.components(separatedBy: "\n")
            var diffLines: [DiffLine] = []
            for (i, line) in leftLines.enumerated() {
                diffLines.append(DiffLine(
                    leftLineNumber: i + 1, rightLineNumber: nil,
                    leftText: line, rightText: nil,
                    type: .removed, inlineChanges: nil
                ))
            }
            let hunks = diffLines.isEmpty ? [] : [DiffHunk(startIndex: 0, endIndex: diffLines.count - 1, lines: diffLines)]
            return FileDiffResult(
                leftPath: leftURL, rightPath: rightURL,
                lines: diffLines, hunks: hunks, isBinary: false,
                leftEncoding: leftEncoding, rightEncoding: rightEncoding
            )
        }

        let leftLines = leftText.components(separatedBy: "\n")
        let rightLines = rightText.components(separatedBy: "\n")

        let editScript = myersDiff(old: leftLines, new: rightLines)
        let diffLines = buildDiffLines(leftLines: leftLines, rightLines: rightLines, editScript: editScript)
        let hunks = buildHunks(from: diffLines)

        return FileDiffResult(
            leftPath: leftURL, rightPath: rightURL,
            lines: diffLines, hunks: hunks, isBinary: false,
            leftEncoding: leftEncoding, rightEncoding: rightEncoding
        )
    }

    // MARK: - Myers Diff Algorithm

    private enum EditOp {
        case equal
        case insert
        case delete
    }

    private static func myersDiff(old: [String], new: [String]) -> [EditOp] {
        let n = old.count
        let m = new.count
        let max = n + m

        if max == 0 { return [] }

        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []

        func idx(_ k: Int) -> Int { k + max }

        outer: for d in 0...max {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[idx(k - 1)] < v[idx(k + 1)]) {
                    x = v[idx(k + 1)]
                } else {
                    x = v[idx(k - 1)] + 1
                }
                var y = x - k

                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }

                v[idx(k)] = x

                if x >= n && y >= m {
                    break outer
                }
            }
        }

        // Backtrack
        var ops: [EditOp] = []
        var x = n
        var y = m

        for d in stride(from: trace.count - 1, through: 1, by: -1) {
            let prevV = trace[d - 1]
            let k = x - y

            var prevK: Int
            if k == -(d) || (k != d && prevV[idx(k - 1)] < prevV[idx(k + 1)]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = prevV[idx(prevK)]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                ops.append(.equal)
                x -= 1
                y -= 1
            }

            if d > 0 {
                if x == prevX {
                    ops.append(.insert)
                    y -= 1
                } else {
                    ops.append(.delete)
                    x -= 1
                }
            }
        }

        while x > 0 && y > 0 && old[x - 1] == new[y - 1] {
            ops.append(.equal)
            x -= 1
            y -= 1
        }

        return ops.reversed()
    }

    // MARK: - Build Diff Lines

    private static func buildDiffLines(leftLines: [String], rightLines: [String], editScript: [EditOp]) -> [DiffLine] {
        var result: [DiffLine] = []
        var leftIdx = 0
        var rightIdx = 0
        var pendingDeletes: [(Int, String)] = []
        var pendingInserts: [(Int, String)] = []

        func flushPending() {
            let pairCount = min(pendingDeletes.count, pendingInserts.count)
            for i in 0..<pairCount {
                let (lNum, lText) = pendingDeletes[i]
                let (rNum, rText) = pendingInserts[i]
                let inlineChanges = computeInlineChanges(left: lText, right: rText)
                result.append(DiffLine(
                    leftLineNumber: lNum, rightLineNumber: rNum,
                    leftText: lText, rightText: rText,
                    type: .modified, inlineChanges: inlineChanges
                ))
            }
            for i in pairCount..<pendingDeletes.count {
                let (lNum, lText) = pendingDeletes[i]
                result.append(DiffLine(
                    leftLineNumber: lNum, rightLineNumber: nil,
                    leftText: lText, rightText: nil,
                    type: .removed, inlineChanges: nil
                ))
            }
            for i in pairCount..<pendingInserts.count {
                let (rNum, rText) = pendingInserts[i]
                result.append(DiffLine(
                    leftLineNumber: nil, rightLineNumber: rNum,
                    leftText: nil, rightText: rText,
                    type: .added, inlineChanges: nil
                ))
            }
            pendingDeletes.removeAll()
            pendingInserts.removeAll()
        }

        for op in editScript {
            switch op {
            case .equal:
                flushPending()
                let text = leftLines[leftIdx]
                result.append(DiffLine(
                    leftLineNumber: leftIdx + 1, rightLineNumber: rightIdx + 1,
                    leftText: text, rightText: text,
                    type: .unchanged, inlineChanges: nil
                ))
                leftIdx += 1
                rightIdx += 1
            case .delete:
                pendingDeletes.append((leftIdx + 1, leftLines[leftIdx]))
                leftIdx += 1
            case .insert:
                pendingInserts.append((rightIdx + 1, rightLines[rightIdx]))
                rightIdx += 1
            }
        }
        flushPending()
        return result
    }

    // MARK: - Inline Changes (character-level diff)

    private static func computeInlineChanges(left: String, right: String) -> [InlineChange]? {
        guard left != right else { return nil }

        let leftChars = Array(left)
        let rightChars = Array(right)

        // Find common prefix
        var prefixLen = 0
        while prefixLen < leftChars.count && prefixLen < rightChars.count && leftChars[prefixLen] == rightChars[prefixLen] {
            prefixLen += 1
        }

        // Find common suffix
        var suffixLen = 0
        while suffixLen < (leftChars.count - prefixLen) && suffixLen < (rightChars.count - prefixLen) &&
              leftChars[leftChars.count - 1 - suffixLen] == rightChars[rightChars.count - 1 - suffixLen] {
            suffixLen += 1
        }

        let leftStart = left.index(left.startIndex, offsetBy: prefixLen)
        let leftEnd = left.index(left.endIndex, offsetBy: -suffixLen)
        let rightStart = right.index(right.startIndex, offsetBy: prefixLen)
        let rightEnd = right.index(right.endIndex, offsetBy: -suffixLen)

        if leftStart < leftEnd || rightStart < rightEnd {
            return [InlineChange(
                leftRange: leftStart < leftEnd ? leftStart..<leftEnd : nil,
                rightRange: rightStart < rightEnd ? rightStart..<rightEnd : nil
            )]
        }
        return nil
    }

    // MARK: - Build Hunks

    private static func buildHunks(from lines: [DiffLine]) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentHunkLines: [DiffLine] = []
        var hunkStart = -1

        for (index, line) in lines.enumerated() {
            if line.type != .unchanged {
                if currentHunkLines.isEmpty {
                    hunkStart = index
                }
                currentHunkLines.append(line)
            } else if !currentHunkLines.isEmpty {
                hunks.append(DiffHunk(startIndex: hunkStart, endIndex: index - 1, lines: currentHunkLines))
                currentHunkLines = []
            }
        }

        if !currentHunkLines.isEmpty {
            hunks.append(DiffHunk(startIndex: hunkStart, endIndex: lines.count - 1, lines: currentHunkLines))
        }

        return hunks
    }

    // MARK: - File Reading

    private static func readFile(at url: URL) -> (Data, String.Encoding) {
        guard let data = try? Data(contentsOf: url) else {
            return (Data(), .utf8)
        }

        // Try UTF-8 first, then Latin-1 (which always succeeds), fallback to ASCII
        if String(data: data, encoding: .utf8) != nil {
            return (data, .utf8)
        } else if String(data: data, encoding: .isoLatin1) != nil {
            return (data, .isoLatin1)
        } else {
            return (data, .ascii)
        }
    }

    private static func isBinary(_ data: Data) -> Bool {
        let checkLength = min(data.count, 8192)
        for i in 0..<checkLength {
            if data[i] == 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Merge Operations

    enum MergeDirection {
        case leftToRight
        case rightToLeft
    }

    // Apply a hunk in-memory, returning new dest lines without writing to disk
    static func applyHunkInMemory(destLines: [String], diffResult: FileDiffResult, hunkIndex: Int, direction: MergeDirection) -> [String]? {
        guard hunkIndex < diffResult.hunks.count else { return nil }
        var result = destLines
        let hunk = diffResult.hunks[hunkIndex]
        var sourceLines: [String] = []
        var destLineNumbers: [Int] = []

        for line in hunk.lines {
            switch direction {
            case .leftToRight:
                if let text = line.leftText { sourceLines.append(text) }
                if let num = line.rightLineNumber { destLineNumbers.append(num) }
            case .rightToLeft:
                if let text = line.rightText { sourceLines.append(text) }
                if let num = line.leftLineNumber { destLineNumbers.append(num) }
            }
        }

        if let firstDest = destLineNumbers.first {
            let startIdx = firstDest - 1
            let safeStart = min(startIdx, result.count)
            let safeEnd = min(safeStart + destLineNumbers.count, result.count)
            result.replaceSubrange(safeStart..<safeEnd, with: sourceLines)
        } else {
            let insertIdx: Int
            if direction == .leftToRight {
                insertIdx = hunk.lines.first.flatMap { $0.rightLineNumber.map { $0 - 1 } } ?? result.count
            } else {
                insertIdx = hunk.lines.first.flatMap { $0.leftLineNumber.map { $0 - 1 } } ?? result.count
            }
            result.insert(contentsOf: sourceLines, at: min(insertIdx, result.count))
        }
        return result
    }

    static func copyLeftToRight(leftURL: URL, rightURL: URL, diffResult: FileDiffResult, hunkIndex: Int) -> Bool {
        let encoding = diffResult.rightEncoding
        let destData = (try? Data(contentsOf: rightURL)) ?? Data()
        let destLines = (String(data: destData, encoding: encoding) ?? "").components(separatedBy: "\n")
        guard let newLines = applyHunkInMemory(destLines: destLines, diffResult: diffResult, hunkIndex: hunkIndex, direction: .leftToRight) else { return false }
        return (try? newLines.joined(separator: "\n").write(to: rightURL, atomically: true, encoding: encoding)) != nil
    }

    static func copyRightToLeft(leftURL: URL, rightURL: URL, diffResult: FileDiffResult, hunkIndex: Int) -> Bool {
        let encoding = diffResult.leftEncoding
        let destData = (try? Data(contentsOf: leftURL)) ?? Data()
        let destLines = (String(data: destData, encoding: encoding) ?? "").components(separatedBy: "\n")
        guard let newLines = applyHunkInMemory(destLines: destLines, diffResult: diffResult, hunkIndex: hunkIndex, direction: .rightToLeft) else { return false }
        return (try? newLines.joined(separator: "\n").write(to: leftURL, atomically: true, encoding: encoding)) != nil
    }
}
