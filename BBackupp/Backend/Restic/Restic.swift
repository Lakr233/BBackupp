//
//  Restic.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/15.
//

import AuxiliaryExecute
import Foundation

enum Restic {
    static let executable = Bundle.main.url(forAuxiliaryExecutable: "restic")!.path
    static let version: String = {
        var stdout = AuxiliaryExecute.spawn(
            command: executable,
            args: ["version"]
        ).stdout
        stdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return stdout
    }()

    static let defaultPassword = "787031d4-00b2-4e33-835d-c382346f5166"
}
