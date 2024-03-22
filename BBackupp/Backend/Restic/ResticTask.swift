//
//  ResticTask.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import AuxiliaryExecute
import Foundation

class ResticTask: ObservableObject, Identifiable {
    var id: UUID = .init()
    let date = Date()
}
