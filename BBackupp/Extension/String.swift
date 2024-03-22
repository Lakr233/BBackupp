//
//  String.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/16.
//

import Foundation

extension String {
    func paddingInt(len: Int) -> String {
        var str = String(self)
        while str.count < len {
            str = "0" + str
        }
        return str
    }
}
