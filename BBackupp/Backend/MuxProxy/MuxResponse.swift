//
//  MuxResponse.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

//
// MuxResponse.result
//
// ok = 0
// badCommand = 1
// badDev = 2
// connRefused = 3
// badVersion = 6
//

struct MuxResponse {
    var length: UInt32
    var version: UInt32
    var message: UInt32
    var tag: UInt32
    var payload: Data

    init(length: UInt32, version: UInt32, message: UInt32, tag: UInt32, /* result: UInt32, */ payload: Data) {
        self.length = length
        self.version = version
        self.message = message
        self.tag = tag
        self.payload = payload
    }

    enum DecodeError: Error {
        case notEnoughData
    }

    init(data: Data) throws {
        guard data.count > MemoryLayout<UInt32>.size else { throw DecodeError.notEnoughData }
        length = UInt32(data[0 ... 3].withUnsafeBytes { $0.load(as: UInt32.self) })
        guard data.count == length else { throw DecodeError.notEnoughData }
        version = UInt32(data[4 ... 7].withUnsafeBytes { $0.load(as: UInt32.self) })
        message = UInt32(data[8 ... 11].withUnsafeBytes { $0.load(as: UInt32.self) })
        tag = UInt32(data[12 ... 15].withUnsafeBytes { $0.load(as: UInt32.self) })
        payload = data[16 ..< length]

//        NSLog("MuxResponse >>>")
//        print("\(String(data: payload, encoding: .utf8) ?? "?")")
//        NSLog("MuxResponse <<<")
    }

    func serialize() -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: length) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: version) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: message) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: tag) { Data($0) })
        data.append(payload)
        assert(data.count == length)
        return data
    }
}
