//
//  NoConfirmSavePanel.swift
//  BBackupp
//
//  Created by QAQ on 2023/8/18.
//

import Cocoa

class NoConfirmSavePanel: NSSavePanel {
    @objc func _overwriteExistingFileCheck(filename: NSString) -> Bool {
        _ = filename
        return false
    }
}
