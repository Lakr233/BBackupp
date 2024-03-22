//
//  Data.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import CommonCrypto
import Foundation

extension Data {
    var sha1sum: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        withUnsafeBytes { ptr in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(count), &digest)
        }
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    var sha256sum: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(count), &digest)
        }
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }
}
