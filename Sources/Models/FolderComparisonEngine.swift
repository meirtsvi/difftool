import Foundation
import CryptoKit

class FolderComparisonEngine {
    static func compare(leftFolder: URL, rightFolder: URL) async -> [FileComparisonResult] {
        let fm = FileManager.default
        let leftFiles = enumerateFiles(at: leftFolder, fm: fm)
        let rightFiles = enumerateFiles(at: rightFolder, fm: fm)

        let allPaths = Set(leftFiles.keys).union(Set(rightFiles.keys))
        var results: [FileComparisonResult] = []

        for path in allPaths {
            let leftInfo = leftFiles[path]
            let rightInfo = rightFiles[path]

            let status: FileStatus
            if let leftInfo, let rightInfo {
                if leftInfo.isDirectory && rightInfo.isDirectory {
                    status = .identical
                } else if leftInfo.isDirectory != rightInfo.isDirectory {
                    status = .modified
                } else {
                    status = filesAreIdentical(
                        leftFolder.appendingPathComponent(path),
                        rightFolder.appendingPathComponent(path)
                    ) ? .identical : .modified
                }
            } else if leftInfo != nil {
                status = .leftOnly
            } else {
                status = .rightOnly
            }

            let fileName = (path as NSString).lastPathComponent
            results.append(FileComparisonResult(
                relativePath: path,
                fileName: fileName,
                status: status,
                leftSize: leftInfo?.size,
                rightSize: rightInfo?.size,
                leftDate: leftInfo?.modDate,
                rightDate: rightInfo?.modDate,
                isDirectory: leftInfo?.isDirectory ?? rightInfo?.isDirectory ?? false
            ))
        }

        return results.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private struct FileInfo {
        let size: Int64
        let modDate: Date
        let isDirectory: Bool
    }

    private static func enumerateFiles(at folder: URL, fm: FileManager) -> [String: FileInfo] {
        var result: [String: FileInfo] = [:]
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        let basePath = folder.path
        for case let fileURL as URL in enumerator {
            let fullPath = fileURL.path
            guard fullPath.hasPrefix(basePath) else { continue }
            let relativePath = String(fullPath.dropFirst(basePath.count + 1))
            if relativePath.isEmpty { continue }

            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                let isDir = resourceValues.isDirectory ?? false
                let size = Int64(resourceValues.fileSize ?? 0)
                let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                result[relativePath] = FileInfo(size: size, modDate: modDate, isDirectory: isDir)
            } catch {
                continue
            }
        }
        return result
    }

    private static func filesAreIdentical(_ left: URL, _ right: URL) -> Bool {
        guard let leftData = try? Data(contentsOf: left),
              let rightData = try? Data(contentsOf: right) else {
            return false
        }
        let leftHash = SHA256.hash(data: leftData)
        let rightHash = SHA256.hash(data: rightData)
        return leftHash == rightHash
    }
}
