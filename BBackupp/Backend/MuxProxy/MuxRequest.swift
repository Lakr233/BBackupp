//
//  MuxRequest.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/1/4.
//

import Foundation
import NIO

//
// MuxRequest.message
//
// result = 1
// connect = 2
// listen = 3
// deviceAdd = 4
// deviceRemove = 5
// devicePaired = 6
// plist = 8
//

struct MuxRequest {
    var length: UInt32 // length of message, including header
    var version: UInt32
    var message: UInt32
    var tag: UInt32 // responses to this query will echo back this tag
    var payload: Data

    init(length: UInt32, version: UInt32, message: UInt32, tag: UInt32, payload: Data, originalData _: Data) {
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
        guard data.count > MemoryLayout<UInt32>.size else {
            throw DecodeError.notEnoughData
        }
        length = UInt32(data[0 ... 3].withUnsafeBytes { $0.load(as: UInt32.self) })
        guard data.count == length else {
            throw DecodeError.notEnoughData
        }
        version = UInt32(data[4 ... 7].withUnsafeBytes { $0.load(as: UInt32.self) })
        message = UInt32(data[8 ... 11].withUnsafeBytes { $0.load(as: UInt32.self) })
        tag = UInt32(data[12 ... 15].withUnsafeBytes { $0.load(as: UInt32.self) })
        payload = data[16 ..< length]

//        NSLog("MuxRequest >>>")
//        print("\(String(data: payload, encoding: .utf8) ?? "?")")
//        NSLog("MuxRequest <<<")
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
