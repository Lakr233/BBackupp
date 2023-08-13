//
//  CryptoKit.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/15.
//

import CryptoKit
import Foundation

enum Crypto {
    static func SHA256(forFile url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        var hasher = CryptoKit.SHA256()
        while autoreleasepool(invoking: {
            let nextChunk = handle.readData(ofLength: CryptoKit.SHA256.blockByteCount)
            guard !nextChunk.isEmpty else { return false }
            hasher.update(data: nextChunk)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
