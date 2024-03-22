//
//  DecodeSize.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import Foundation

enum SizeDecoder {
    static func decode(_ input: String) -> Int? {
        guard let value = input.components(separatedBy: " ").first,
              let unit = input.components(separatedBy: " ").last,
              let valueDouble = Double(value)
        else { return nil }
        switch unit {
        case "Bytes": return Int(valueDouble)
        case "KB": return Int(valueDouble * 1000)
        case "MB": return Int(valueDouble * 1000 * 1000)
        case "GB": return Int(valueDouble * 1000 * 1000 * 1000)
        case "TB": return Int(valueDouble * 1000 * 1000 * 1000 * 1000)
        case "KiB": return Int(valueDouble * 1024)
        case "MiB": return Int(valueDouble * 1024 * 1024)
        case "GiB": return Int(valueDouble * 1024 * 1024 * 1024)
        case "TiB": return Int(valueDouble * 1024 * 1024 * 1024 * 1024)
        default: return nil
        }
    }
}
