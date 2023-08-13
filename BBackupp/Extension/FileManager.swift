//
//  FileManager.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import Foundation

private let byteCountFormatter: ByteCountFormatter = {
    let fmt = ByteCountFormatter()
    fmt.countStyle = .file
    return fmt
}()

extension URL {
    var mountPoint: URL {
        guard let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [],
            options: [.produceFileReferenceURLs]
        ) else { return URL(fileURLWithPath: "/") }
        var urlFinder = self
        while urlFinder.pathComponents.count > 0 {
            if mountedVolumes.contains(urlFinder) {
                return urlFinder
            }
            urlFinder.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: "/")
    }

    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        return try checkResourceIsReachable()
    }

    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else { return nil }
        if includingSubfolders {
            guard
                let urls = FileManager.default.enumerator(
                    at: self,
                    includingPropertiesForKeys: nil
                )?.allObjects as? [URL]
            else { return nil }
            return try urls.lazy.reduce(0) {
                try ($1.resourceValues(
                    forKeys: [.totalFileAllocatedSizeKey]
                ).totalFileAllocatedSize ?? 0) + $0
            }
        }
        return try FileManager.default.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: nil
        )
        .lazy
        .reduce(0) {
            try ($1.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey]
            )
            .totalFileAllocatedSize ?? 0) + $0
        }
    }

    func getFreeSpaceSize() -> UInt64? {
        do {
            let fileAttributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            if let freeSize = fileAttributes[FileAttributeKey.systemFreeSize] as? NSNumber {
                return freeSize.uint64Value
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    func getTotalSpaceSize() -> UInt64? {
        do {
            let fileAttributes = try FileManager.default.attributesOfFileSystem(forPath: path)
            if let freeSize = fileAttributes[FileAttributeKey.systemSize] as? NSNumber {
                return freeSize.uint64Value
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    func getFreeSpaceSize() -> String {
        guard let size = getFreeSpaceSize() else { return "???" }
        return byteCountFormatter.string(fromByteCount: Int64(size))
    }

    func getTotalSpaceSize() -> String {
        guard let size = getTotalSpaceSize() else { return "???" }
        return byteCountFormatter.string(fromByteCount: Int64(size))
    }

    func fileSize() -> UInt64 {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attr[FileAttributeKey.size] as? UInt64
        else { return 0 }
        return size
    }
}
