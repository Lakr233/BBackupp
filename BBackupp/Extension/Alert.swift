//
//  Alert.swift
//  BBackupp
//
//  Created by 秋星桥 on 2024/3/7.
//

import AppKit

extension NSApplication {
    func alertError(message: String) {
        guard let window = keyWindow else { return }
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in
        }
    }

    func alertError(error: Error) {
        alertError(message: error.localizedDescription)
    }
}
