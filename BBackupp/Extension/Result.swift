//
//  Result.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
//

import Foundation

public extension Result where Success == Void {
    static func success() -> Self { .success(()) }
}
