//
//  Codable.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import Foundation

protocol CopyableCodable: Codable {
    func codableCopy() -> Self?
}

extension CopyableCodable {
    func codableCopy() -> Self? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
