//
//  String.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/13.
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
